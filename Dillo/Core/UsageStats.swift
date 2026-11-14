import Foundation

/// Statistiche calcolate dalla cronologia per la pagina Panoramica.
struct UsageStats {
    struct AppUsage: Identifiable {
        let name: String
        let bundleID: String?
        let words: Int
        let dictations: Int
        var id: String { bundleID ?? name }
    }

    var totalWords = 0
    var totalDictations = 0
    var totalSeconds = 0.0
    var corrections = 0
    var wordsThisMonth = 0
    var wordsLastMonth = 0
    var apps: [AppUsage] = []
    var engines: [(name: String, words: Int)] = []
    var dailyWords: [Date: Int] = [:]
    var currentStreak = 0
    var longestStreak = 0
    var averageLatency = 0.0
    var averageDuration = 0.0
    var longestDictation = 0.0

    /// Parole al minuto mentre parli.
    var wordsPerMinute: Int { totalSeconds > 5 ? Int(Double(totalWords) / (totalSeconds / 60)) : 0 }
    /// Velocità media di battitura su tastiera usata come riferimento.
    static let typingWPM = 40.0
    var timesFasterThanTyping: Double { Double(wordsPerMinute) / Self.typingWPM }
    /// Minuti risparmiati rispetto a scrivere a mano.
    var minutesSaved: Int { max(0, Int(Double(totalWords) / Self.typingWPM - totalSeconds / 60)) }
    var monthTrend: Double? {
        guard wordsLastMonth > 0 else { return nil }
        return Double(wordsThisMonth - wordsLastMonth) / Double(wordsLastMonth)
    }

    init() {}

    init(transcripts: [Transcript], calendar cal: Calendar = .current, now: Date = .now) {
        var appMap: [String: (name: String, bundle: String?, words: Int, count: Int)] = [:]
        var engineMap: [String: Int] = [:]
        let thisMonth = cal.dateInterval(of: .month, for: now)
        let lastMonth = thisMonth.flatMap { cal.dateInterval(of: .month, for: $0.start.addingTimeInterval(-1)) }
        var latencySum = 0.0

        for t in transcripts {
            let w = t.wordCount
            totalWords += w
            totalDictations += 1
            totalSeconds += t.duration
            corrections += t.corrections
            latencySum += t.latency
            longestDictation = max(longestDictation, t.duration)
            if thisMonth?.contains(t.createdAt) == true { wordsThisMonth += w }
            if lastMonth?.contains(t.createdAt) == true { wordsLastMonth += w }
            dailyWords[cal.startOfDay(for: t.createdAt), default: 0] += w
            let key = t.appBundleID ?? t.appName ?? "Sconosciuta"
            var entry = appMap[key] ?? (t.appName ?? "Sconosciuta", t.appBundleID, 0, 0)
            entry.words += w; entry.count += 1
            appMap[key] = entry
            engineMap[t.engine, default: 0] += w
        }
        apps = appMap.values.map { AppUsage(name: $0.name, bundleID: $0.bundle, words: $0.words, dictations: $0.count) }
            .sorted { $0.words > $1.words }
        engines = engineMap.map { ($0.key, $0.value) }.sorted { $0.words > $1.words }
        if totalDictations > 0 {
            averageLatency = latencySum / Double(totalDictations)
            averageDuration = totalSeconds / Double(totalDictations)
        }

        // Serie di giorni consecutivi
        let days = Set(dailyWords.keys)
        var run = 0, best = 0
        for day in days.sorted() {
            if let prev = cal.date(byAdding: .day, value: -1, to: day), days.contains(prev) { run += 1 } else { run = 1 }
            best = max(best, run)
        }
        longestStreak = best
        var cursor = cal.startOfDay(for: now)
        if !days.contains(cursor) { cursor = cal.date(byAdding: .day, value: -1, to: cursor)! }
        while days.contains(cursor) {
            currentStreak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
    }
}
