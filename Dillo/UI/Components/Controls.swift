import SwiftUI

// Componenti condivisi che danno a Dillo un aspetto coerente e "da prodotto":
// campi di testo, pulsanti, tasti, righe delle impostazioni.

/// Campo di testo scuro con bordo sottile e anello corallo quando è attivo.
struct DilloTextFieldStyle: TextFieldStyle {
    @FocusState private var focused: Bool
    var height: CGFloat = 36

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($focused)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(focused ? Theme.coral.opacity(0.7) : Theme.stroke, lineWidth: focused ? 1.5 : 1))
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}

extension TextFieldStyle where Self == DilloTextFieldStyle {
    static var dillo: DilloTextFieldStyle { DilloTextFieldStyle() }
}

/// Pulsante principale: corallo pieno.
struct PrimaryButtonStyle: ButtonStyle {
    var large = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 15 : 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, large ? 22 : 14)
            .frame(height: large ? 46 : 32)
            .frame(maxWidth: large ? .infinity : nil)
            .background(Theme.coral.opacity(configuration.isPressed ? 0.8 : (hover ? 0.9 : 1)),
                        in: RoundedRectangle(cornerRadius: large ? 12 : 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: large ? 12 : 9, style: .continuous)
                .strokeBorder(.white.opacity(0.14)))
            .shadow(color: Theme.coral.opacity(large ? 0.35 : 0), radius: 14, y: 6)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .onHover { hover = $0 }
            .animation(reduceMotion ? nil : Theme.interaction, value: configuration.isPressed)
            .animation(reduceMotion ? nil : Theme.interaction, value: hover)
    }
}

/// Pulsante secondario discreto, come il "Cambia" delle impostazioni.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : (hover ? 0.1 : 0.07)),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.stroke))
            .opacity(enabled ? 1 : 0.45)
            .onHover { hover = $0 }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryLarge: PrimaryButtonStyle { PrimaryButtonStyle(large: true) }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Un tasto della tastiera disegnato, es. ⌥ o fn.
struct KeyCap: View {
    let label: String
    var size: CGFloat = 22
    var accent = false

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
            .foregroundStyle(accent ? .white : .white.opacity(0.85))
            .padding(.horizontal, size * 0.32)
            .frame(minWidth: size, minHeight: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(accent ? AnyShapeStyle(Theme.coral) : AnyShapeStyle(Color.white.opacity(0.08)))
                    .shadow(color: .black.opacity(0.4), radius: 0, y: size * 0.06)
            )
            .overlay(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .strokeBorder(Color.white.opacity(accent ? 0.2 : 0.12)))
    }
}

/// Gruppo di righe su sfondo leggermente rialzato (stile impostazioni di sistema, più morbido).
struct SettingsGroup<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Eyebrow(title).padding(.leading, 4) }
            VStack(spacing: 0) {
                _VariadicView.Tree(DividedLayout()) { content() }
            }
            .background(Theme.raised.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
            if let footer {
                Text(footer).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Inserisce un separatore sottile tra le righe di un gruppo.
private struct DividedLayout: _VariadicView_MultiViewRoot {
    @ViewBuilder func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        ForEach(children) { child in
            child
            if child.id != last {
                Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 18)
            }
        }
    }
}

/// Riga delle impostazioni: titolo, descrizione/valore e un controllo a destra.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var detail: String?
    var symbol: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 30, height: 30)
                    .background(Theme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                if let detail {
                    Text(detail).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 60)
    }
}
