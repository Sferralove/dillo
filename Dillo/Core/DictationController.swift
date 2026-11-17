import AppKit
import Observation
import SwiftData

enum DictationState: Equatable {
    case downloading(Double), loadingModel, idle, recording, transcribing
    case error(String)

    var symbol: String {
        switch self {
        case .downloading: "arrow.down.circle"
        case .loadingModel: "hourglass"
        case .idle: "waveform"
        case .recording: "mic.fill"
        case .transcribing: "ellipsis.circle"
        case .error: "exclamationmark.triangle"
        }
    }

    var isError: Bool { if case .error = self { true } else { false } }

    var unavailableMessage: String? {
        switch self {
        case .downloading: "Modello in download. Riprova quando è pronto."
        case .loadingModel: "Modello non ancora pronto. Riprova tra poco."
        case .error: "Motore non disponibile. Controlla Dillo per riprovare."
        case .transcribing: "Trascrizione in corso. Riprova tra poco."
        case .idle, .recording: nil
        }
    }

    var title: String {
        switch self {
        case .downloading(let p): "Scarico il modello · \(Int(p * 100))%"
        case .loadingModel: "Preparo il motore…"
        case .idle: "Pronto"
        case .recording: "Ti ascolto"
        case .transcribing: "Trascrivo…"
        case .error: "Errore"
        }
    }
}

/// Da dove è partita la registrazione: dal tasto globale (incolla nell'app attiva)
/// o dal pulsante nella finestra di Dillo (salva solo nella cronologia).
enum RecordingSource { case hotkey, app }

@MainActor
@Observable
final class DictationController {
    // Stato osservabile
    private(set) var state: DictationState = .loadingModel {
        didSet { syncMenuBarIcon() }
    }
    let menuBarIcon = MenuBarIconModel()
    private(set) var level: Float = 0
    private(set) var partialText = ""
    private(set) var lastLatency: Duration?
    private(set) var notice: String?
    private(set) var hudWarning: String?
    /// Cambia a ogni nuova trascrizione salvata (per l'onboarding e per chi osserva l'ultimo risultato).
    private(set) var lastTranscriptID = 0
    private(set) var lastTranscriptText: String?
    private(set) var recordingStartedAt: Date?
    private(set) var axGranted = AXIsProcessTrusted()
    private(set) var micGranted = Permissions.microphoneGranted
    /// Il microfono non sta captando nulla dall'inizio della registrazione.
    private(set) var micSilent = false
    /// Lingua diversa rilevata nelle ultime dettature, da proporre all'utente.
    private(set) var languageSuggestion: SpeechLanguage?
    /// Microfoni disponibili, aggiornati quando si collega o scollega un dispositivo.
    private(set) var inputDevices: [AudioInputDevice] = []
    /// Nome del microfono predefinito di sistema in questo momento.
    private(set) var defaultInputName: String?
    var errorMessage: String? { if case .error(let m) = state { m } else { nil } }

    // Preferenze (persistite in UserDefaults)
    var engineKind: EngineKind {
        didSet { guard engineKind != oldValue else { return }; defaults.set(engineKind.rawValue, forKey: Pref.engine); rebuildEngine() }
    }
    var languageID: String {
        didSet { guard languageID != oldValue else { return }; defaults.set(languageID, forKey: Pref.language); rebuildEngine() }
    }
    var hotkeyKey: HotkeyKey {
        didSet { defaults.set(hotkeyKey.rawValue, forKey: Pref.hotkeyKey); hotkey.key = hotkeyKey }
    }
    var hotkeyMode: HotkeyMode {
        didSet { defaults.set(hotkeyMode.rawValue, forKey: Pref.hotkeyMode) }
    }
    var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Pref.autoPaste) } }
    var playSounds: Bool { didSet { defaults.set(playSounds, forKey: Pref.sounds) } }
    /// Giorni di cronologia da conservare; 0 = per sempre.
    var retentionDays: Int { didSet { defaults.set(retentionDays, forKey: Pref.retentionDays); pruneHistory() } }
    var showHUD: Bool { didSet { defaults.set(showHUD, forKey: Pref.showHUD); hud?.update() } }
    /// UID del microfono scelto; nil = predefinito di sistema.
    var microphoneUID: String? {
        didSet { defaults.set(microphoneUID, forKey: Pref.microphone); recorder.deviceUID = microphoneUID }
    }

    var isRecording: Bool { state == .recording }
    var isReady: Bool { state == .idle }
    var engineName: String { engine.displayName }

    let container: ModelContainer
    private let defaults = UserDefaults.standard
    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private let inserter = TextInserter()
    private var engine: any SpeechEngine
    private var hud: HUDController?
    private var loadTask: Task<Void, Never>?
    private var source: RecordingSource = .hotkey
    private var targetApp: String?
    private var targetBundleID: String?
    private var targetPID: pid_t?
    private var peakLevel: Float = 0
    private var silenceTask: Task<Void, Never>?
    private var detectedLanguage: (code: String, hits: Int)?
    private var dismissedLanguages: Set<String> = []
    private var deviceObserver: AnyObject?
    /// La dettatura dal tasto non è ancora "confermata": suono e indicatore arrivano dopo un attimo,
    /// così una combinazione come ⌥ò (@) non fa partire nulla di visibile.
    private var confirmTask: Task<Void, Never>?
    private var warningTask: Task<Void, Never>?
    private var unavailableHoldTask: Task<Void, Never>?
    private var vocabularyCache: (signature: [VocabularyEntry], compiled: CompiledVocabulary)?

    /// Pressioni del tasto più brevi di così sono considerate un tocco involontario.
    private static let minimumHold: Duration = .milliseconds(250)
    /// Ritardo prima di suono e indicatore quando la dettatura parte dal tasto tenuto premuto.
    private static let confirmDelay: Duration = .milliseconds(180)
    /// Entro quanto tempo dalla pressione un altro tasto trasforma la dettatura in una combinazione.
    private static let chordWindow: TimeInterval = 1

    init(container: ModelContainer, startServices: Bool = true) {
        self.container = container
        let d = UserDefaults.standard
        let kind = EngineKind(rawValue: d.string(forKey: Pref.engine) ?? "") ?? .apple
        let lang = d.string(forKey: Pref.language) ?? "it-IT"
        engineKind = kind
        languageID = lang
        hotkeyKey = HotkeyKey(rawValue: d.string(forKey: Pref.hotkeyKey) ?? "") ?? .rightOption
        hotkeyMode = HotkeyMode(rawValue: d.string(forKey: Pref.hotkeyMode) ?? "") ?? .hold
        autoPaste = d.object(forKey: Pref.autoPaste) as? Bool ?? true
        showHUD = d.object(forKey: Pref.showHUD) as? Bool ?? true
        microphoneUID = d.string(forKey: Pref.microphone)
        playSounds = d.object(forKey: Pref.sounds) as? Bool ?? true
        retentionDays = d.integer(forKey: Pref.retentionDays)
        engine = Self.makeEngine(kind, language: lang)

        hud = HUDController(controller: self)
        recorder.deviceUID = microphoneUID
        syncMenuBarIcon()
        recorder.onLevel = { [weak self] l in
            Task { @MainActor in
                guard let self else { return }
                self.level = l
                self.menuBarIcon.push(level: l)
                self.peakLevel = max(self.peakLevel, l)
                if self.micSilent, l > Self.silenceThreshold { self.micSilent = false; self.hud?.update() }
            }
        }
        hotkey.key = hotkeyKey
        hotkey.onPress = { [weak self] in self?.hotkeyPressed() }
        hotkey.onRelease = { [weak self] held, chorded in self?.hotkeyReleased(heldFor: held, chorded: chorded) }
        hotkey.onChord = { [weak self] in self?.hotkeyChorded() }
        hotkey.onCancel = { [weak self] in self?.cancel() }
        refreshInputDevices()
        guard startServices else { state = .idle; return }
        deviceObserver = AudioDevices.observeChanges { [weak self] in
            self?.refreshInputDevices()
            self?.recorder.invalidate()
        }
        hotkey.start()
        loadEngine()
        pruneHistory()
        Task { [weak self] in
            while let self {
                // Assegna solo se cambia: ogni assegnazione notifica le viste che osservano il valore.
                let ax = AXIsProcessTrusted(), mic = Permissions.microphoneGranted
                if self.axGranted != ax { self.axGranted = ax }
                if self.micGranted != mic { self.micGranted = mic }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refreshInputDevices() {
        let devices = AudioDevices.inputs()
        if devices != inputDevices { inputDevices = devices }
        let name = AudioDevices.defaultInputName
        if name != defaultInputName { defaultInputName = name }
    }

    /// Sotto questa soglia (≈ -48 dB) consideriamo il microfono muto.
    private static let silenceThreshold: Float = 0.15

    private func startSilenceWatch() {
        peakLevel = 0
        micSilent = false
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard let self, !Task.isCancelled, self.isRecording, self.peakLevel < Self.silenceThreshold else { return }
            self.micSilent = true
            self.hud?.update()
        }
    }

    // MARK: - Lingua

    /// Analizza il testo finale: se due dettature di fila sembrano in un'altra lingua supportata, la propone.
    private func checkLanguage(of text: String) {
        guard text.split(separator: " ").count >= 5 else { return }
        let current = String(languageID.prefix(2))
        guard let code = LanguageDetector.dominantLanguage(of: text, current: current),
              code != current, !dismissedLanguages.contains(code),
              let suggestion = SpeechLanguage.matching(code: code) else {
            detectedLanguage = nil
            return
        }
        let hits = detectedLanguage?.code == code ? detectedLanguage!.hits + 1 : 1
        detectedLanguage = (code, hits)
        if hits >= 2 { languageSuggestion = suggestion }
    }

    func acceptLanguageSuggestion() {
        guard let suggestion = languageSuggestion else { return }
        languageSuggestion = nil
        detectedLanguage = nil
        languageID = suggestion.id
    }

    func dismissLanguageSuggestion() {
        if let s = languageSuggestion { dismissedLanguages.insert(String(s.id.prefix(2))) }
        languageSuggestion = nil
        detectedLanguage = nil
    }

    private func syncMenuBarIcon() {
        switch state {
        case .idle: menuBarIcon.set(mode: .idle)
        case .recording: menuBarIcon.set(mode: .recording)
        case .transcribing, .loadingModel, .downloading: menuBarIcon.set(mode: .busy)
        case .error: menuBarIcon.set(mode: .error)
        }
    }

    private static func makeEngine(_ kind: EngineKind, language: String) -> any SpeechEngine {
        switch kind {
        case .apple: AppleSpeechEngine(locale: Locale(identifier: language))
        case .parakeet: ParakeetEngine(languageCode: language)
        }
    }

    private func rebuildEngine() {
        guard !isRecording, state != .transcribing else { return }
        engine = Self.makeEngine(engineKind, language: languageID)
        loadEngine()
    }

    func loadEngine() {
        loadTask?.cancel()
        state = .loadingModel
        let engine = self.engine
        let owner = WeakController(self)
        loadTask = Task {
            do {
                try await engine.prepare { phase in
                    Task { @MainActor in owner.value?.apply(phase, for: engine) }
                }
                guard let me = owner.value, engine === me.engine else { return }
                me.state = .idle
            } catch {
                guard let me = owner.value, engine === me.engine else { return }
                me.state = .error(error.localizedDescription)
            }
        }
    }

    /// Avanzamento del caricamento, ignorato se nel frattempo il motore è cambiato o è già pronto.
    private func apply(_ phase: ModelLoadPhase, for engine: any SpeechEngine) {
        guard engine === self.engine, !state.isError, state != .idle else { return }
        switch phase {
        case .downloading(let p): state = .downloading(p)
        case .loading: state = .loadingModel
        }
    }

    // MARK: - Hotkey

    private func hotkeyPressed() {
        // In modalità "premi per avviare" si agisce al rilascio, quando sappiamo che non era una combinazione.
        if hotkeyMode == .hold {
            if state.unavailableMessage != nil {
                unavailableHoldTask?.cancel()
                unavailableHoldTask = Task { [weak self] in
                    try? await Task.sleep(for: Self.minimumHold)
                    guard !Task.isCancelled else { return }
                    self?.showUnavailableWarning()
                }
            } else { start(from: .hotkey) }
        }
    }

    private func hotkeyReleased(heldFor held: Duration, chorded: Bool) {
        unavailableHoldTask?.cancel()
        unavailableHoldTask = nil
        switch hotkeyMode {
        case .hold:
            guard source == .hotkey else { return }
            // Se una combinazione l'ha già annullata, stop() e cancel() non fanno nulla.
            if held < Self.minimumHold { cancel(silently: true) } else { stop() }
        case .toggle:
            guard !chorded else { return }
            isRecording ? stop() : start(from: .hotkey)
        }
    }

    /// Il tasto di dettatura è stato usato per scrivere (es. ⌥ò → @): non era una dettatura.
    private func hotkeyChorded() {
        unavailableHoldTask?.cancel()
        unavailableHoldTask = nil
        guard hotkeyMode == .hold, source == .hotkey, let started = recordingStartedAt else { return }
        // Solo nel primo secondo: un tasto sfiorato a metà di una dettatura lunga non deve buttarla via.
        guard Date.now.timeIntervalSince(started) < Self.chordWindow else { return }
        cancel(silently: true)
    }

    func toggleFromApp() {
        isRecording ? stop() : start(from: .app)
    }

    // MARK: - Registrazione

    func start(from source: RecordingSource) {
        guard state == .idle else { showUnavailableWarning(); return }
        warningTask?.cancel()
        hudWarning = nil
        self.source = source
        let target = NSWorkspace.shared.frontmostApplication
        targetApp = target?.localizedName
        targetBundleID = target?.bundleIdentifier
        targetPID = target?.processIdentifier
        partialText = ""
        notice = nil
        let engine = self.engine
        engine.begin(vocabulary: vocabulary().map(\.term)) { [weak self] text in
            Task { @MainActor in
                guard let self, self.state == .recording else { return }
                self.partialText = text
            }
        }
        recorder.onBuffer = { engine.append($0) }
        do {
            try recorder.start()
            recordingStartedAt = .now
            state = .recording
            hotkey.isRecording = true
            startSilenceWatch()
        } catch {
            state = .error(error.localizedDescription)
            hud?.update()
            return
        }
        confirmTask?.cancel()
        if source == .hotkey && hotkeyMode == .hold {
            confirmTask = Task { [weak self] in
                try? await Task.sleep(for: Self.confirmDelay)
                guard let self, !Task.isCancelled, self.isRecording else { return }
                self.confirmStart()
            }
        } else {
            confirmStart()
        }
    }

    private func showUnavailableWarning() {
        guard let message = state.unavailableMessage else { return }
        hudWarning = message
        hud?.update()
        warningTask?.cancel()
        warningTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            self.hudWarning = nil
            self.hud?.update()
        }
    }

    private func confirmStart() {
        confirmTask = nil
        sound("Tink")
        hud?.update()
    }

    func stop() {
        guard state == .recording else { return }
        if confirmTask != nil { confirmTask?.cancel(); confirmStart() }
        let released = ContinuousClock.now
        let duration = recordingStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        recorder.stop()
        recorder.onBuffer = nil
        hotkey.isRecording = false
        silenceTask?.cancel()
        sound("Pop")
        let wasSilent = peakLevel < Self.silenceThreshold
        micSilent = false
        recordingStartedAt = nil
        level = 0
        state = .transcribing
        hud?.update()
        let engine = self.engine
        let source = self.source
        Task {
            do {
                let raw = try await engine.finish()
                let (text, corrections) = compiledVocabulary().apply(raw)
                let latency = ContinuousClock.now - released
                lastLatency = latency
                partialText = ""
                if !text.isEmpty {
                    save(text: text, duration: duration, latency: latency, corrections: corrections)
                    lastTranscriptText = text
                    lastTranscriptID += 1
                    // Non incollare dentro Dillo stesso (es. durante l'onboarding).
                    if source == .hotkey && autoPaste && targetBundleID != Bundle.main.bundleIdentifier {
                        switch await inserter.insert(text + " ", targetPID: targetPID) {
                        case .pasted: notice = nil
                        case .copiedOnly: notice = "Accessibilità non concessa: il testo è negli appunti, premi ⌘V."
                        case .destinationChanged: notice = "L’app attiva è cambiata: il testo è negli appunti, premi ⌘V dove vuoi inserirlo."
                        }
                    } else if source == .app {
                        notice = "Trascrizione salvata nella cronologia."
                    }
                    checkLanguage(of: raw)
                } else if wasSilent {
                    notice = "Il microfono non ha captato nulla. Controlla il microfono scelto nelle Impostazioni."
                }
                state = .idle
            } catch {
                state = .error(error.localizedDescription)
            }
            hud?.update()
        }
    }

    func dismissError() {
        if state.isError { loadEngine() }
    }

    // MARK: - Dati

    private func vocabulary() -> [VocabularyEntry] {
        let entries = (try? container.mainContext.fetch(FetchDescriptor<DictionaryEntry>())) ?? []
        return entries.map { VocabularyEntry(term: $0.term, variants: $0.variantList) }
    }

    /// Dizionario con le espressioni regolari già compilate: si ricompila solo quando il dizionario cambia.
    private func compiledVocabulary() -> CompiledVocabulary {
        let entries = vocabulary()
        if let cache = vocabularyCache, cache.signature == entries { return cache.compiled }
        let compiled = CompiledVocabulary(entries)
        vocabularyCache = (entries, compiled)
        return compiled
    }

    /// Annulla la dettatura in corso (Esc): nessun testo viene incollato né salvato.
    /// `silently`: per i tocchi involontari e le combinazioni di tasti, senza avvisi.
    func cancel(silently: Bool = false) {
        guard state == .recording else { return }
        let wasVisible = confirmTask == nil
        confirmTask?.cancel()
        confirmTask = nil
        recorder.stop()
        recorder.onBuffer = nil
        hotkey.isRecording = false
        silenceTask?.cancel()
        micSilent = false
        recordingStartedAt = nil
        level = 0
        partialText = ""
        if !silently { notice = "Dettatura annullata." }
        let engine = self.engine
        state = .transcribing
        Task {
            _ = try? await engine.finish()      // chiude la sessione del motore e scarta il risultato
            state = .idle
            hud?.update()
        }
        if wasVisible { hud?.update() }
    }

    private func sound(_ name: String) {
        guard playSounds, let s = NSSound(named: NSSound.Name(name)) else { return }
        s.volume = 0.35
        s.play()
    }

    // MARK: - Gestione della cronologia

    /// Elimina le trascrizioni più vecchie del periodo di conservazione scelto.
    func pruneHistory() {
        guard retentionDays > 0,
              let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) else { return }
        try? container.mainContext.delete(model: Transcript.self, where: #Predicate { $0.createdAt < cutoff })
        try? container.mainContext.save()
    }

    func deleteAllHistory() {
        try? container.mainContext.delete(model: Transcript.self)
        try? container.mainContext.save()
    }

    private func save(text: String, duration: Double, latency: Duration, corrections: Int) {
        let seconds = Double(latency.components.seconds) + Double(latency.components.attoseconds) / 1e18
        let item = Transcript(text: text, duration: duration, latency: seconds,
                              engine: engine.displayName,
                              appName: source == .hotkey ? targetApp : "Dillo",
                              appBundleID: source == .hotkey ? targetBundleID : Bundle.main.bundleIdentifier,
                              corrections: corrections)
        container.mainContext.insert(item)
        try? container.mainContext.save()
    }
}

/// Riferimento debole al controller passabile tra task concorrenti.
private struct WeakController: @unchecked Sendable {
    weak var value: DictationController?
    init(_ value: DictationController) { self.value = value }
}
