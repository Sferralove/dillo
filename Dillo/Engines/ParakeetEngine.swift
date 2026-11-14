import AVFoundation
import FluidAudio

/// Parakeet TDT 0.6B v3 (NVIDIA) via FluidAudio, su Neural Engine.
/// Non è in streaming nativo: accumula l'audio, aggiorna l'anteprima sugli ultimi secondi
/// e al rilascio trascrive tutto (≈ 100x tempo reale su M4, quindi resta molto rapido).
final class ParakeetEngine: SpeechEngine, @unchecked Sendable {
    var displayName: String { "Parakeet v3" }
    private let language: Language?
    private var manager: AsrManager?

    private static let sampleRate = 16_000.0
    private let lock = NSLock()
    private var samples: [Float] = []
    private var active = false
    private let converter = PCMConverter(target: AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                                               channels: 1, interleaved: false)!)
    private var previewTask: Task<Void, Never>?

    init(languageCode: String) {
        language = Language(rawValue: String(languageCode.prefix(2)))
    }

    func prepare(onPhase: @escaping @Sendable (ModelLoadPhase) -> Void) async throws {
        if manager != nil { return }
        let cached = AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: .v3))
        onPhase(cached ? .loading : .downloading(0))
        // Rete instabile (es. errori TLS sul CDN di Hugging Face): fino a 3 tentativi con attesa crescente.
        var models: AsrModels?
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                models = try await AsrModels.downloadAndLoad(version: .v3, progressHandler: { p in
                    onPhase(p.fractionCompleted < 1 ? .downloading(p.fractionCompleted) : .loading)
                })
                break
            } catch {
                lastError = error
                try? await Task.sleep(for: .seconds(2 << attempt))
            }
        }
        guard let models else { throw lastError ?? CancellationError() }
        onPhase(.loading)
        let m = AsrManager(config: .default)
        try await m.loadModels(models)
        manager = m
        // Riscaldamento: la prima inferenza compila i kernel sul Neural Engine.
        _ = try? await transcribe([Float](repeating: 0, count: Int(Self.sampleRate)))
    }

    func begin(vocabulary: [String], onPartial: @escaping @Sendable (String) -> Void) {
        lock.withLock { samples.removeAll(keepingCapacity: true); active = true }
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            while !Task.isCancelled {
                guard let self else { return }
                let window: [Float] = self.lock.withLock {
                    let n = Int(12 * Self.sampleRate)
                    return self.samples.count > n ? Array(self.samples.suffix(n)) : self.samples
                }
                if window.count > Int(0.5 * Self.sampleRate),
                   let text = try? await self.transcribe(window), !Task.isCancelled, !text.isEmpty {
                    onPartial(text)
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard active, let out = converter.convert(buffer), let ch = out.floatChannelData?[0] else { return }
        samples.append(contentsOf: UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
    }

    func finish() async throws -> String {
        let preview = previewTask
        previewTask = nil
        preview?.cancel()
        await preview?.value          // AsrManager: una trascrizione alla volta
        let all = lock.withLock { active = false; return samples }
        guard all.count > Int(0.25 * Self.sampleRate) else { return "" }
        return try await transcribe(all)
    }

    private func transcribe(_ s: [Float]) async throws -> String {
        guard let manager else { return "" }
        var audio = s
        if audio.count < Int(Self.sampleRate) { audio += [Float](repeating: 0, count: Int(Self.sampleRate) - audio.count) }
        var state = TdtDecoderState.make()
        let result = try await manager.transcribe(audio, decoderState: &state, language: language)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Modello Parakeet su disco (cache di FluidAudio).
enum ParakeetStorage {
    static var directory: URL { AsrModels.defaultCacheDirectory(for: .v3) }

    static func size() -> Int64? {
        guard let e = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else { return nil }
        var total: Int64 = 0
        for case let url as URL in e {
            total += Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        return total > 0 ? total : nil
    }

    static func delete() {
        try? FileManager.default.trashItem(at: directory, resultingItemURL: nil)
    }
}
