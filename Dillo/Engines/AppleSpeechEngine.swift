import AVFoundation
import Speech

/// Motore nativo di macOS 26 (SpeechAnalyzer + SpeechTranscriber), in streaming.
/// Il modello della lingua lo scarica e lo gestisce macOS.
final class AppleSpeechEngine: SpeechEngine, @unchecked Sendable {
    let locale: Locale
    var displayName: String { "Apple Speech" }
    private var analyzerFormat: AVAudioFormat?

    private let lock = NSLock()
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var converter: PCMConverter?
    private var resultsTask: Task<String, Error>?
    private var startTask: Task<Void, Error>?

    init(locale: Locale) { self.locale = locale }

    private func makeModule() -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [],
                          reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
    }

    func prepare(onPhase: @escaping @Sendable (ModelLoadPhase) -> Void) async throws {
        guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else {
            throw NSError(domain: "AppleSpeech", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Lingua \(locale.identifier) non supportata da Apple Speech"])
        }
        let module = makeModule()
        if await AssetInventory.status(forModules: [module]) != .installed,
           let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            onPhase(.downloading(0))
            let observer = request.progress.observe(\.fractionCompleted) { p, _ in onPhase(.downloading(p.fractionCompleted)) }
            try await request.downloadAndInstall()
            observer.invalidate()
        }
        onPhase(.loading)
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
        let warm = SpeechAnalyzer(modules: [module], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        try await warm.prepareToAnalyze(in: analyzerFormat)
    }

    func begin(vocabulary: [String], onPartial: @escaping @Sendable (String) -> Void) {
        let module = makeModule()
        let analyzer = SpeechAnalyzer(modules: [module], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let format = analyzerFormat

        let results = Task<String, Error> {
            var finalized = ""
            for try await result in module.results {
                let text = String(result.text.characters)
                if result.isFinal { finalized += text; onPartial(finalized) }
                else { onPartial(finalized + text) }
            }
            return finalized
        }
        let start = Task {
            if !vocabulary.isEmpty {
                let context = AnalysisContext()
                context.contextualStrings[.general] = vocabulary
                try await analyzer.setContext(context)
            }
            try await analyzer.prepareToAnalyze(in: format)
            try await analyzer.start(inputSequence: stream)
        }
        lock.withLock {
            self.analyzer = analyzer
            self.input = continuation
            self.converter = format.map(PCMConverter.init(target:))
            self.resultsTask = results
            self.startTask = start
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard let input, let out = converter?.convert(buffer) else { return }
        input.yield(AnalyzerInput(buffer: out))
    }

    func finish() async throws -> String {
        let (analyzer, input, results, start) = lock.withLock {
            let v = (self.analyzer, self.input, self.resultsTask, self.startTask)
            self.analyzer = nil; self.input = nil; self.resultsTask = nil; self.startTask = nil; self.converter = nil
            return v
        }
        input?.finish()
        try await start?.value
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        let text = try await results?.value ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
