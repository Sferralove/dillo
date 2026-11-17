import SwiftUI

/// Palette di Dillo — minimal scuro con accento corallo.
enum Theme {
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.353)        // #FF6B5A
    static let coralSoft = Color(red: 1.0, green: 0.60, blue: 0.48)
    static let graphite = Color(red: 0.067, green: 0.071, blue: 0.078)  // #111214  sfondo
    static let surface = Color(red: 0.098, green: 0.102, blue: 0.114)   // #191A1D  pannelli
    static let raised = Color(red: 0.13, green: 0.135, blue: 0.15)      // #212226  card
    static let stroke = Color.white.opacity(0.07)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)
    /// Scala corallo per grafici e heatmap (dal più tenue al più intenso).
    static let coralScale: [Color] = [coral.opacity(0.18), coral.opacity(0.4), coral.opacity(0.68), coral]
    static let barGradient = LinearGradient(colors: [coralSoft, coral], startPoint: .top, endPoint: .bottom)
    static let cardGradient = LinearGradient(colors: [Color.white.opacity(0.055), Color.white.opacity(0.015)],
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

/// Tipografia "editoriale": titoli e numeri in serif (New York), etichette in maiuscoletto spaziato.
enum Typo {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .serif) }
    static let pageTitle = Font.system(size: 30, weight: .semibold, design: .serif)
    static let eyebrow = Font.system(size: 10.5, weight: .semibold)
    static let body = Font.system(size: 13)
}

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(Typo.eyebrow)
            .tracking(1.4)
            .foregroundStyle(Theme.textSecondary)
    }
}
