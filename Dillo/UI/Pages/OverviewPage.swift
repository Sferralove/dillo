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
            PageHeader(title: "Insights") {
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
                    .id(tab)
                    .transition(.opacity)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Utilizzo

    private func usage(_ s: UsageStats, wide: Bool) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .top), count: wide ? 3 : 1)
        return VStack(spacing: 18) {
            LazyVGrid(columns: columns, spacing: 18) {
                speedCard(s).reveal(0)
                correctionsCard(s).reveal(1)
                wordsCard(s).reveal(2)
            }
            .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .top), count: wide ? 2 : 1), spacing: 18) {
                appsCard(s).reveal(3)
                StatCard {
                    ActivityHeatmap(daily: s.dailyWords, streak: s.currentStreak, longest: s.longestStreak)
                }
                .reveal(4)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func speedCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 8) {
                BigNumber(s.wordsPerMinute)
                Eyebrow("Parole al minuto")
                Spacer(minLength: 4)
                SpeedGauge(wpm: s.wordsPerMinute).frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(minHeight: 190)
        }
    }

    private func correctionsCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 8) {
                BigNumber(s.corrections + dictionary.count)
                Eyebrow("Correzioni di Dillo")
                Divider().overlay(Theme.stroke).padding(.vertical, 14)
                MetricRow(value: s.corrections, label: "parole corrette")
                MetricRow(value: dictionary.count, label: "voci nel dizionario")
                Spacer(minLength: 0)
            }
            .frame(minHeight: 190)
        }
    }

    private func wordsCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    BigNumber(s.totalWords)
                    Spacer()
                    if let trend = s.monthTrend { TrendBadge(trend: trend) }
                }
                Eyebrow("Parole dettate · totale")
                Divider().overlay(Theme.stroke).padding(.vertical, 14)
                Text(milestone(s.totalWords)).font(.system(size: 16))
                Spacer(minLength: 8)
                EngineSplit(engines: s.engines, total: s.totalWords)
            }
            .frame(minHeight: 190)
        }
    }

    private func appsCard(_ s: UsageStats) -> some View {
        StatCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Uso per app").font(Typo.display(30))
                    Spacer(minLength: 8)
                    Eyebrow("App usate | \(s.apps.count)")
                }
                if s.apps.isEmpty {
                    EmptyHint("Detta in qualsiasi app con la scorciatoia: qui vedrai dove usi di più Dillo.")
                } else {
                    let top = s.apps.first.map { Double($0.words) / Double(max(s.totalWords, 1)) } ?? 1
                    ForEach(Array(s.apps.prefix(6).enumerated()), id: \.element.id) { i, app in
                        HStack(spacing: 14) {
                            AppIcon(bundleID: app.bundleID, size: 22)
                            ProportionBar(fraction: Double(app.words) / Double(max(s.totalWords, 1)), scale: top,
                                          color: [Theme.accent, Theme.accentScale[2], Theme.accentScale[1], Theme.accentScale[1]][min(i, 3)], height: 38, index: i)
                            Text("\(app.words.formatted()) · \(app.name)".uppercased())
                                .font(Typo.eyebrow).tracking(1).foregroundStyle(Theme.textSecondary)
                                .lineLimit(1).frame(width: 150, alignment: .leading)
                        }
                    }
                }
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
        return [Theme.accent, Theme.accent.opacity(0.75), Theme.accent.opacity(0.55), Theme.accent.opacity(0.4)][min(idx, 3)]
    }
}

// MARK: - Componenti locali

private struct BigNumber: View {
    let value: Int
    init(_ value: Int) { self.value = value }
    var body: some View {
        CountingText(value: value)
            .font(.system(size: 36, weight: .regular))
    }
}

private struct MetricRow: View {
    let value: Int
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            CountingText(value: value, duration: 0.9).font(.system(size: 17, weight: .medium))
            Text(label).font(.system(size: 17))
            Spacer()
        }
        .padding(.vertical, 5)
    }
}

private struct TrendBadge: View {
    let trend: Double
    var body: some View {
        Label(String(format: "%+.1f%% questo mese", trend * 100),
              systemImage: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.accentScale[0].opacity(trend >= 0 ? 0.7 : 0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Barra segmentata per motore, con etichetta dentro ogni segmento.
private struct EngineSplit: View {
    let engines: [(name: String, words: Int)]
    let total: Int
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if engines.isEmpty {
            Text("I motori usati appariranno qui.").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
        } else {
            GeometryReader { geo in
                HStack(spacing: 4) {
                    ForEach(Array(engines.prefix(3).enumerated()), id: \.offset) { i, engine in
                        let share = Double(engine.words) / Double(max(total, 1))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill([Theme.accent, Theme.accentScale[2], Theme.accentScale[1]][i])
                            .frame(width: max(geo.size.width * share - 4, 30))
                            .overlay {
                                Text(engine.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                                    .lineLimit(1).padding(.horizontal, 8)
                            }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 28)
            .scaleEffect(x: grown || reduceMotion ? 1 : 0.02, anchor: .leading)
            .opacity(grown || reduceMotion ? 1 : 0)
            .onAppear { withAnimation(.spring(duration: 0.9, bounce: 0.08).delay(0.5)) { grown = true } }
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
        .reveal(0)
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
                                .foregroundStyle(selection == item ? Theme.ink : Theme.textSecondary)
                            ZStack {
                                Rectangle().fill(.clear).frame(height: 2)
                                if selection == item {
                                    Rectangle().fill(Theme.accent).frame(height: 2).matchedGeometryEffect(id: "tab", in: ns)
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
