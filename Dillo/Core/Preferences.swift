import AppKit

enum EngineKind: String, CaseIterable, Identifiable, Sendable {
    case apple, parakeet
    var id: String { rawValue }
    var title: String {
        switch self {
        case .apple: "Apple Speech"
        case .parakeet: "Parakeet v3"
        }
    }
    var subtitle: String {
        switch self {
        case .apple: "Nativo di macOS · streaming in tempo reale · nessun download nell'app"
        case .parakeet: "NVIDIA via FluidAudio · 25 lingue europee · ~500 MB, scaricato una volta"
        }
    }
    var symbol: String {
        switch self {
        case .apple: "apple.logo"
        case .parakeet: "bird"
        }
    }
}

enum HotkeyKey: String, CaseIterable, Identifiable, Sendable {
    case rightOption, leftOption, rightCommand, rightControl, fn
    var id: String { rawValue }
    var keyCode: UInt16 {
        switch self {
        case .rightOption: 61
        case .leftOption: 58
        case .rightCommand: 54
        case .rightControl: 62
        case .fn: 63
        }
    }
    var flag: NSEvent.ModifierFlags {
        switch self {
        case .rightOption, .leftOption: .option
        case .rightCommand: .command
        case .rightControl: .control
        case .fn: .function
        }
    }
    var title: String {
        switch self {
        case .rightOption: "Option destro"
        case .leftOption: "Option sinistro"
        case .rightCommand: "Command destro"
        case .rightControl: "Control destro"
        case .fn: "Fn / Globo"
        }
    }
    var glyph: String {
        switch self {
        case .rightOption: "⌥ destro"
        case .leftOption: "⌥ sinistro"
        case .rightCommand: "⌘ destro"
        case .rightControl: "⌃ destro"
        case .fn: "fn"
        }
    }
}

enum HotkeyMode: String, CaseIterable, Identifiable, Sendable {
    case hold, toggle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hold: "Tieni premuto"
        case .toggle: "Premi per avviare e fermare"
        }
    }
}

struct SpeechLanguage: Identifiable, Hashable, Sendable {
    let id: String      // BCP-47
    let name: String
    static let all: [SpeechLanguage] = [
        .init(id: "it-IT", name: "Italiano"),
        .init(id: "en-US", name: "English (US)"),
        .init(id: "en-GB", name: "English (UK)"),
        .init(id: "es-ES", name: "Español"),
        .init(id: "fr-FR", name: "Français"),
        .init(id: "de-DE", name: "Deutsch"),
        .init(id: "pt-PT", name: "Português"),
    ]

    /// Lingua dell'elenco corrispondente a un codice ISO (es. "en" → English (US)).
    static func matching(code: String) -> SpeechLanguage? {
        all.first { $0.id.hasPrefix(code + "-") }
    }

    /// Nome della lingua nella lingua dell'interfaccia (es. "inglese").
    var localizedName: String {
        Locale(identifier: "it").localizedString(forLanguageCode: String(id.prefix(2))) ?? name
    }
}

/// Chiavi UserDefaults.
enum Pref {
    static let engine = "engine"
    static let language = "language"
    static let hotkeyKey = "hotkeyKey"
    static let hotkeyMode = "hotkeyMode"
    static let autoPaste = "autoPaste"
    static let showHUD = "showHUD"
    static let microphone = "microphoneUID"
    static let onboarded = "onboardingCompleted"
    static let sounds = "playSounds"
    static let retentionDays = "historyRetentionDays"
}

/// Modalità dimostrativa (solo build Debug con `-demo`): dati di esempio, nessun dato personale.
enum AppMode {
    static var isDemo: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-demo")
        #else
        false
        #endif
    }
}
