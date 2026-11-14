import SwiftData
import SwiftUI

struct OverviewPage: View {
    @Query(sort: \Transcript.createdAt, order: .reverse) private var transcripts: [Transcript]
    @Query private var dictionary: [DictionaryEntry]
    @State private var tab: Tab = .usage

    enum Tab: String, CaseIterable { case usage = "Il tuo utilizzo", voice = "La tua voce" }

    private var stats: UsageStats { UsageStats(transcripts: transcripts) }

    var body: some View {
        let stats = self.stats
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(title: greeting, subtitle: subtitle(stats)) {
                    TabStrip(selection: $tab)
                }
                Group {
                    switch tab {
                    case .usage: usage(stats)
                    case .voice: voice(stats)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 36)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Utilizzo

    @ViewBuilder private func usage(_ s: UsageStats) -> some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                StatCard {
                    VStack(alignment: .leading, spacing: 4) {
                        BigNumber(s.wordsPerMinute)
                        Eyebrow("Parole al minuto")
                        SpeedGauge(wpm: s.wordsPerMinute)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                    }
                }
                StatCard {
                    VStack(alignment: .leading, spacing: 4) {
                        BigNumber(s.corrections)
                        Eyebrow("Correzioni del dizionario")
                        Divider().overlay(Theme.stroke).padding(.vertical, 14)
                        MetricRow(label: "Voci nel dizionario", value: dictionary.count)
                        MetricRow(label: "Minuti risparmiati", value: s.minutesSaved)
                        MetricRow(label: "Dettature", value: s.totalDictations)
                    }
                }
                StatCard {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            BigNumber(s.totalWords)
                            Spacer()
                            if let trend = s.monthTrend { TrendBadge(trend: trend) }
                        }
                        Eyebrow("Parole dettate in totale")
                        Divider().overlay(Theme.stroke).padding(.vertical, 14)
                        Text(milestone(s.totalWords))
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.bottom, 12)
                        EngineSplit(engines: s.engines, total: s.totalWords)
                    }
                }
                .frame(minWidth: 320)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 18) {
                StatCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Dove detti").font(Typo.display(24))
                            Spacer()
                            Eyebrow("App usate · \(s.apps.count)")
                        }
                        if s.apps.isEmpty {
                            EmptyHint("Detta in qualsiasi app con la scorciatoia: qui vedrai dove usi di più Dillo.")
                        } else {
                            ForEach(s.apps.prefix(6)) { app in
                                HStack(spacing: 12) {
                                    AppIcon(bundleID: app.bundleID)
                                    ProportionBar(fraction: Double(app.words) / Double(max(s.totalWords, 1)),
                                                  color: color(for: app, in: s))
                                        .frame(maxWidth: 260)
                                    Text("\(app.words.formatted()) parole · \(app.name)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(0.6)
                                        .textCase(.uppercase)
                                        .foregroundStyle(.white.opacity(0.75))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                }
                StatCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(s.currentStreak == 1 ? "1 giorno di fila" : "\(s.currentStreak) giorni di fila")
                                .font(Typo.display(24))
                            Spacer()
                            Eyebrow("Record · \(s.longestStreak) giorni")
                        }
                        ActivityHeatmap(daily: s.dailyWords)
                    }
                }
                .frame(minWidth: 470)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Voce

    @ViewBuilder private func voice(_ s: UsageStats) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 18)], spacing: 18) {
            VoiceTile(value: String(format: "%.2f s", s.averageLatency), label: "Latenza media al rilascio",
                      note: "Tempo tra la fine della dettatura e il testo pronto.")
            VoiceTile(value: String(format: "%.1f s", s.averageDuration), label: "Durata media",
                      note: "Quanto parli in media ogni volta.")
            VoiceTile(value: String(format: "%.0f s", s.longestDictation), label: "Dettatura più lunga",
                      note: "Il tuo monologo record.")
            VoiceTile(value: s.totalDictations > 0 ? "\(s.totalWords / s.totalDictations)" : "—", label: "Parole per dettatura",
                      note: "Lunghezza media di ogni trascrizione.")
            VoiceTile(value: "\(Int(s.totalSeconds / 60))", label: "Minuti parlati",
                      note: "Tempo totale di dettatura registrato.")
            VoiceTile(value: "\(s.wordsThisMonth.formatted())", label: "Parole questo mese",
                      note: s.monthTrend.map { String(format: "%+.0f%% rispetto al mese scorso", $0 * 100) } ?? "Primo mese di utilizzo.")
        }
    }

    // MARK: Testi

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        let salute = h < 13 ? "Buongiorno" : (h < 18 ? "Buon pomeriggio" : "Buonasera")
        return first.isEmpty ? salute : "\(salute), \(first)"
    }

    private func subtitle(_ s: UsageStats) -> String {
        s.totalDictations == 0
            ? "Inizia a dettare: le tue statistiche prenderanno forma qui."
            : "\(s.totalDictations) dettature · \(s.minutesSaved) minuti risparmiati rispetto alla tastiera"
    }

    private func milestone(_ words: Int) -> String {
        switch words {
        case 0: return "La prima parola è la più importante."
        case ..<300: return "Hai dettato \(words) parole: il primo paragrafo è fatto."
        case ..<600: return "Hai riempito la tua prima pagina con la voce."
        case ..<3_000: return "Hai riempito \(words / 300) pagine con la voce."
        case ..<6_000: return "Hai dettato l'equivalente di un capitolo intero."
        case ..<60_000: return "Hai dettato l'equivalente di \(words / 3_000) capitoli."
        case ..<120_000: return "Hai scritto un libro completo a voce!"
        default: return "Hai scritto \(words / 60_000) libri completi a voce!"
        }
    }

    private func color(for app: UsageStats.AppUsage, in s: UsageStats) -> Color {
        let idx = s.apps.firstIndex { $0.id == app.id } ?? 0
        return [Theme.coral, Theme.coral.opacity(0.75), Theme.coral.opacity(0.55), Theme.coral.opacity(0.4)][min(idx, 3)]
    }
}

// MARK: - Componenti locali

private struct BigNumber: View {
    let value: Int
    init(_ value: Int) { self.value = value }
    var body: some View {
        Text(value.formatted())
            .font(Typo.display(40))
            .contentTransition(.numericText())
            .animation(.snappy, value: value)
    }
}

private struct MetricRow: View {
    let label: String
    let value: Int
    var body: some View {
        HStack {
            Text("\(Text(value.formatted()).font(.system(size: 15, weight: .medium, design: .serif))) \(Text(label.lowercased()).font(.system(size: 13.5)).foregroundColor(.white.opacity(0.8)))")
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct TrendBadge: View {
    let trend: Double
    var body: some View {
        Label(String(format: "%+.1f%% questo mese", trend * 100),
              systemImage: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(trend >= 0 ? Theme.coral : Theme.textSecondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Theme.coral.opacity(trend >= 0 ? 0.13 : 0.05), in: Capsule())
    }
}

private struct EngineSplit: View {
    let engines: [(name: String, words: Int)]
    let total: Int
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 4) {
                if engines.isEmpty {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06))
                } else {
                    ForEach(Array(engines.enumerated()), id: \.offset) { i, e in
                        let frac = Double(e.words) / Double(max(total, 1))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i == 0 ? Theme.coral : Theme.coral.opacity(0.4))
                            .frame(width: max(70, (geo.size.width - 4) * frac))
                            .overlay(alignment: .leading) {
                                Label(e.name, systemImage: e.name.contains("Apple") ? "apple.logo" : "bird")
                                    .font(.system(size: 11, weight: .medium)).padding(.leading, 9)
                                    .lineLimit(1)
                            }
                    }
                }
            }
        }
        .frame(height: 26)
    }
}

private struct VoiceTile: View {
    let value: String, label: String, note: String
    var body: some View {
        StatCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(value).font(Typo.display(34))
                Eyebrow(label)
                Text(note).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).padding(.top, 8)
            }
        }
    }
}

struct TabStrip<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 28) {
                ForEach(T.allCases, id: \.self) { item in
                    Button { withAnimation(.snappy) { selection = item } } label: {
                        VStack(spacing: 9) {
                            Text(item.rawValue)
                                .font(.system(size: 14, weight: selection == item ? .semibold : .regular))
                                .foregroundStyle(selection == item ? .white : Theme.textSecondary)
                            ZStack {
                                Rectangle().fill(.clear).frame(height: 2)
                                if selection == item {
                                    Rectangle().fill(Theme.coral).frame(height: 2).matchedGeometryEffect(id: "tab", in: ns)
                                }
                            }
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
            }
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
        .padding(.top, 8)
    }
}

struct EmptyHint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .multilineTextAlignment(.center)
    }
}
