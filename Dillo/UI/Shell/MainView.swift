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

/// Struttura della finestra: barra a icone a sinistra e pannello di contenuto arrotondato.
struct MainView: View {
    @Environment(DictationController.self) private var controller
    @State private var page: Page

    init(initialPage: Page = .overview) { _page = State(initialValue: initialPage) }

    var body: some View {
        HStack(spacing: 0) {
            IconRail(page: $page)
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
        .background(Theme.graphite)
        .ignoresSafeArea()
    }
}

struct IconRail: View {
    @Binding var page: Page
    @Environment(DictationController.self) private var controller

    var body: some View {
        VStack(spacing: 6) {
            AppMark(size: 30)
                .padding(.top, 50)
                .padding(.bottom, 16)
                .help("Dillo")

            ForEach(Page.allCases) { p in
                RailButton(symbol: p.symbol, title: p.title, selected: page == p) { page = p }
            }

            Spacer()

            RailButton(symbol: controller.isRecording ? "stop.circle.fill" : "mic.circle",
                       title: controller.isRecording ? "Interrompi (⌘R)" : "Registra (⌘R)",
                       selected: controller.isRecording, tint: Theme.coral) {
                controller.toggleFromApp()
            }
            .disabled(!(controller.isReady || controller.isRecording))

            SettingsLink {
                RailIcon(symbol: "gearshape", selected: false)
            }
            .buttonStyle(.plain)
            .help("Impostazioni (⌘,)")
            .padding(.bottom, 14)
        }
        .frame(width: 64)
    }
}

private struct RailButton: View {
    let symbol: String
    let title: String
    let selected: Bool
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) { RailIcon(symbol: symbol, selected: selected, tint: tint) }
            .buttonStyle(.plain)
            .help(title)
    }
}

private struct RailIcon: View {
    let symbol: String
    let selected: Bool
    var tint: Color = .white
    @State private var hover = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(selected ? (tint == .white ? Theme.coral : tint) : .white.opacity(hover ? 0.85 : 0.5))
            .frame(width: 40, height: 40)
            .background(selected ? Theme.coral.opacity(0.13) : Color.white.opacity(hover ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.15), value: hover)
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
