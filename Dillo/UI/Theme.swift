import AppKit
import SwiftUI

extension Color {
    /// Colore che cambia con l'aspetto: scuro per le finestre secondarie, chiaro per la finestra principale.
    init(dark: NSColor, light: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

private func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Tema scelto da riga di comando: `--theme light`, `--theme dark` (o `--theme=dark`). Senza argomento segue il sistema.
enum AppTheme {
    static let override: ColorScheme? = {
        let args = CommandLine.arguments
        var value: String?
        if let i = args.firstIndex(where: { $0 == "--theme" || $0 == "-theme" }), i + 1 < args.count { value = args[i + 1] }
        else if let a = args.first(where: { $0.hasPrefix("--theme=") }) { value = String(a.dropFirst(8)) }
        switch value?.lowercased() {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }()

    /// Da usare con `.preferredColorScheme` in ogni finestra.
    static var colorScheme: ColorScheme? { override }

    /// Aspetto AppKit per finestre, pannelli flottanti e menu; `nil` = sistema.
    static var appearance: NSAppearance? {
        switch override {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        default: nil
        }
    }
}

/// Palette di Dillo. Chiaro: carta calda con accento verde petrolio. Scuro: grafite con accento corallo.
enum Theme {
    static let accent = Color(dark: rgb(0xFF6B5A), light: rgb(0x2D5B5B))
    static let accentSoft = Color(dark: rgb(0xFF9A7A), light: rgb(0x4F8F87))
    /// Sfondo della finestra (attorno al pannello).
    static let graphite = Color(dark: rgb(0x111214), light: rgb(0xF4F2EF))
    /// Pannello principale.
    static let surface = Color(dark: rgb(0x191A1D), light: rgb(0xFBFAF8))
    static let raised = Color(dark: rgb(0x212226), light: rgb(0xF5F3F0))
    /// Colore del testo e dei velature: bianco sul scuro, quasi nero sul chiaro.
    static let ink = Color(dark: .white, light: rgb(0x1E2121))
    static let stroke = Color(dark: NSColor.white.withAlphaComponent(0.07), light: rgb(0xE6E2DC))
    static let textSecondary = Color(dark: NSColor.white.withAlphaComponent(0.55), light: rgb(0x6F706E))
    static let textTertiary = Color(dark: NSColor.white.withAlphaComponent(0.35), light: rgb(0xA3A29E))
    /// Cella vuota nei grafici.
    static let empty = Color(dark: NSColor.white.withAlphaComponent(0.05), light: rgb(0xEFECE7))
    /// Scala per grafici e heatmap (dal più tenue al più intenso).
    static let accentScale: [Color] = [
        Color(dark: rgb(0xFF6B5A, 0.18), light: rgb(0xCFE6E2)),
        Color(dark: rgb(0xFF6B5A, 0.40), light: rgb(0x8CC4B8)),
        Color(dark: rgb(0xFF6B5A, 0.68), light: rgb(0x4F8F87)),
        accent,
    ]
    static let barGradient = LinearGradient(colors: [accentSoft, accent], startPoint: .top, endPoint: .bottom)
    static let cardGradient = LinearGradient(colors: [Color(dark: NSColor.white.withAlphaComponent(0.055), light: .clear),
                                                      Color(dark: NSColor.white.withAlphaComponent(0.015), light: .clear)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let interaction = Animation.easeOut(duration: 0.18)
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke))
    }
}

extension View {
    func card(radius: CGFloat = 14) -> some View { modifier(CardBackground(radius: radius)) }
}

/// Tipografia: titoli e numeri in sans arrotondato pulito, etichette in maiuscoletto spaziato.
enum Typo {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
    static let pageTitle = Font.system(size: 20, weight: .semibold)
    static let eyebrow = Font.system(size: 11.5, weight: .medium)
    static let body = Font.system(size: 13)
}

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(Typo.eyebrow)
            .tracking(1.2)
            .foregroundStyle(Theme.textSecondary)
    }
}
