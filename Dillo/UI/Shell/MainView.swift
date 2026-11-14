import SwiftData
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case overview, history, dictionary
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: "Panoramica"
        case .history: "Cronologia"
        case .dictionary: "Dizionario"
        }
    }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .history: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        }
    }
}

struct SelectedPageKey: FocusedValueKey { typealias Value = Binding<Page> }
extension FocusedValues {
    var selectedPage: Binding<Page>? {
        get { self[SelectedPageKey.self] }
        set { self[SelectedPageKey.self] = newValue }
    }
}

/// Navigazione espandibile; si compatta automaticamente nelle finestre strette.
struct MainView: View {
    @State private var page: Page
    @AppStorage("sidebarExpanded") private var sidebarExpanded = true

    init(initialPage: Page = .overview) { _page = State(initialValue: initialPage) }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                IconRail(page: $page, expanded: sidebarExpanded && geometry.size.width >= 940,
                         canExpand: geometry.size.width >= 940, prefersExpanded: $sidebarExpanded)
                ZStack {
                    switch page {
                    case .overview: OverviewPage()
                    case .history: HistoryPage()
                    case .dictionary: DictionaryPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 38)
                .padding([.trailing, .bottom], 10)
            }
            // Come nelle app Apple: il pulsante della barra laterale sta subito a destra del semaforo.
            .overlay(alignment: .topLeading) {
                SidebarToggle(expanded: sidebarExpanded && geometry.size.width >= 940,
                              canExpand: geometry.size.width >= 940) { sidebarExpanded.toggle() }
                    .padding(.leading, 78)
                    .padding(.top, 4)
            }
        }
        .background(Theme.graphite)
        .ignoresSafeArea()
        .focusedSceneValue(\.selectedPage, $page)
    }
}

struct IconRail: View {
    @Binding var page: Page
    var expanded: Bool
    var canExpand: Bool
    @Binding var prefersExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                AppMark(size: 30)
                if expanded { Text("Dillo").font(Typo.display(23)) }
            }
            .padding(.leading, 5).padding(.top, 50).padding(.bottom, 20)

            ForEach(Page.allCases) { p in
                Button { page = p } label: {
                    railLabel(symbol: p.symbol, title: p.title, selected: page == p)
                }
                .buttonStyle(.plain)
                .help(p.title)
                .accessibilityLabel(p.title)
                .accessibilityAddTraits(page == p ? .isSelected : [])
            }
            Spacer()
            SettingsLink { railLabel(symbol: "gearshape", title: "Impostazioni", selected: false) }
                .buttonStyle(.plain).help("Impostazioni (⌘,)")
                .accessibilityLabel("Impostazioni")
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 12)
        .frame(width: expanded ? 180 : 64)
    }

    private func railLabel(symbol: String, title: String, selected: Bool) -> some View {
        RailLabel(symbol: symbol, title: title, selected: selected, expanded: expanded)
    }
}

private struct RailLabel: View {
    let symbol: String, title: String
    let selected: Bool, expanded: Bool
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 16)).frame(width: 20)
            if expanded { Text(title).font(.system(size: 13, weight: selected ? .semibold : .regular)) }
            if expanded { Spacer(minLength: 0) }
        }
        .foregroundStyle(selected ? Theme.coral : .white.opacity(hover ? 0.95 : 0.65))
        .padding(.horizontal, expanded ? 12 : 10)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(selected ? Theme.coral.opacity(0.13) : Color.white.opacity(hover ? 0.05 : 0),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

/// Il logo di Dillo disegnato in vettoriale (stesso disegno dell'icona dell'app),
/// così è sempre nitido e aggiornato, senza dipendere dalla cache delle icone di macOS.
struct AppMark: View {
    var size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.102, green: 0.106, blue: 0.114),
                                          Color(red: 0.055, green: 0.059, blue: 0.063)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous).strokeBorder(Theme.stroke))
            .overlay(RobinView().frame(width: size * 0.78).offset(x: size * 0.05))
            .frame(width: size, height: size)
    }
}

/// Pulsante della barra laterale nella fascia del titolo, accanto ai pulsanti della finestra.
private struct SidebarToggle: View {
    let expanded: Bool
    let canExpand: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(canExpand ? (hover ? 0.95 : 0.6) : 0.25))
                .frame(width: 30, height: 24)
                .background(Color.white.opacity(hover && canExpand ? 0.08 : 0),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canExpand)
        .onHover { hover = $0 }
        .help(canExpand
              ? (expanded ? "Comprimi la barra laterale (⌃⌘S)" : "Espandi la barra laterale (⌃⌘S)")
              : "Allarga la finestra per espandere la barra laterale")
        .accessibilityLabel(expanded ? "Comprimi barra laterale" : "Espandi barra laterale")
    }
}
