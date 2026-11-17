import SwiftData
import SwiftUI

struct OverviewPage: View {
    @Query(sort: \Transcript.createdAt, order: .reverse) private var transcripts: [Transcript]
    @Query private var dictionary: [DictionaryEntry]
    @State private var tab: Tab = .usage

    enum Tab: String, CaseIterable { case usage = "Il tuo utilizzo", voice = "La tua voce" }

    /// Statistiche in cache: si ricalcolano solo quando cambia la cronologia (o il giorno), non a ogni aggiornamento della vista.
    @State private var cache = StatsCache()

    private final class StatsCache {
        var key: StatsKey?
        var value = UsageStats()
    }

    private var stats: UsageStats {
        let key = statsKey
        if cache.key != key {
            cache.value = UsageStats(transcripts: transcripts)
            cache.key = key
        }
        return cache.value
    }

    fileprivate struct StatsKey: Equatable {
        let count: Int
        let latest: Date?
        let day: Date
    }

    private var statsKey: StatsKey {
        StatsKey(count: transcripts.count, latest: transcripts.first?.createdAt, day: Calendar.current.startOfDay(for: .now))
    }

    var body: some View {
        let stats = self.stats
        VStack(spacing: 0) {
            PageHeader(title: greeting, subtitle: subtitle(stats)) {
                TabStrip(selection: $tab)
            }
            GeometryReader { geometry in
                ScrollView {
                    Group {
                        switch tab {
                        case .usage: usage(stats, wide: geometry.size.width >= 880)
                        case .voice: voice(stats)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Utilizzo

    private func usage(_ s: UsageStats, wide: Bool) -> some View {
        VStack(spacing: 16) {
            if wide {
                GeometryReader { geometry in
                    let unit = (geometry.size.width - 48) / 4
                    HStack(alignment: .top, spacing: 16) {
                        speedCard(s).frame(width: unit)
                        correctionsCard(s).frame(width: unit)
                        wordsCard(s).frame(width: unit * 2 + 16)
                    }
                }
                .frame(height: 204)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 16) {
                    speedCard(s)
                    correctionsCard(s)
                }
                wordsCard(s)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: wide ? 2 : 1), spacing: 16) {
                StatCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Dove detti").font(Typo.display(24))
                        if s.apps.isEmpty {
                            EmptyHint("Detta in qualsiasi app con la scorciatoia: qui vedrai dove usi di più Dillo.")
                        } else {
                            ForEach(s.apps.prefix(6)) { app in
                                HStack(spacing: 12) {
                                    AppIcon(bundleID: app.bundleID, size: 18)
                                    Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1).frame(width: 72, alignment: .leading)
                                    ProportionBar(fraction: Double(app.words) / Double(max(s.totalWords, 1)), color: color(for: app, in: s), height: 24)
                                    Text("\(app.words.formatted())").font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }
                StatCard {
                    ActivityHeatmap(daily: s.dailyWords, streak: s.currentStreak)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 16, alignment: .top)], spacing: 16) {
                monthCard(s)
                StatCard {
                    VStack(alignment: .leading, spacing: 10) {
                        BigNumber(s.minutesSaved)
                        Eyebrow("Minuti risparmiati · stima")
                        Text("Rispetto a scrivere a tastiera, a \(Int(UsageStats.typingWPM)) parole al minuto.")
                            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                }
                StatCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Motori").font(Typo.display(22))
                        EngineSplit(engines: s.engines, total: s.totalWords)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func speedCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 10) {
                BigNumber(s.wordsPerMinute)
                Eyebrow("Parole al minuto")
                SpeedGauge(wpm: s.wordsPerMinute).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func correctionsCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 10) {
                BigNumber(s.corrections)
                Eyebrow("Correzioni applicate")
                Divider().overlay(Theme.stroke).padding(.vertical, 8)
                MetricRow(label: "Voci nel dizionario", value: dictionary.count)
            }
        }
    }

    private func wordsCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    BigNumber(s.totalWords)
                    Spacer()
                    if let trend = s.monthTrend { TrendBadge(trend: trend) }
                }
                Eyebrow("Parole dettate · totale")
                Divider().overlay(Theme.stroke).padding(.vertical, 8)
                Text(milestone(s.totalWords)).font(.system(size: 14, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(s.totalDictations.formatted()) dettature complessive")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func monthCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 10) {
                BigNumber(s.wordsThisMonth)
                Eyebrow("Parole · \(Date.now.formatted(.dateTime.month(.wide).year()))")
                if let trend = s.monthTrend { TrendBadge(trend: trend) }
                else { Text("Nessun confronto disponibile con il mese scorso.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary) }
            }
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
                      note: s.monthTrend.map { String(format: "%+.0f%% rispetto al mese scorso", $0 * 100) } ?? "Nessun confronto con il mese scorso.")
        }
    }

    // MARK: Testi

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        // Nome dell'utente dal sistema; mai negli screenshot dimostrativi.
        let first = AppMode.isDemo ? "" : (NSFullUserName().split(separator: " ").first.map(String.init) ?? "")
        let salute = h < 13 ? "Buongiorno" : (h < 18 ? "Buon pomeriggio" : "Buonasera")
        return first.isEmpty ? salute : "\(salute), \(first)"
    }

    private func subtitle(_ s: UsageStats) -> String {
        s.totalDictations == 0
            ? "Inizia a dettare: le tue statistiche prenderanno forma qui."
            : "La tua attività di dettatura, dall’inizio a oggi."
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
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(engines.enumerated()), id: \.offset) { i, engine in
                HStack(spacing: 8) {
                    Circle().fill(i == 0 ? Theme.coral : Theme.coral.opacity(0.4)).frame(width: 7, height: 7)
                    Text(engine.name).lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(Int((Double(engine.words) / Double(max(total, 1)) * 100).rounded()))%")
                        .monospacedDigit().foregroundStyle(Theme.textSecondary)
                }
                .font(.system(size: 12))
            }
            if engines.isEmpty { Text("I motori usati appariranno qui.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary) }
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 28) {
                ForEach(T.allCases, id: \.self) { item in
                    Button { withAnimation(reduceMotion ? nil : .snappy) { selection = item } } label: {
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
                    .accessibilityAddTraits(selection == item ? .isSelected : [])
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
