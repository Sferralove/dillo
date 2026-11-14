import Foundation
import Testing
@testable import Dillo

@Suite("Statistiche")
struct UsageStatsTests {
    let cal = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func t(_ daysAgo: Int, words: Int = 10, seconds: Double = 6, app: String = "Mail") -> Transcript {
        let text = Array(repeating: "parola", count: words).joined(separator: " ")
        return Transcript(text: text, createdAt: cal.date(byAdding: .day, value: -daysAgo, to: now)!,
                          duration: seconds, latency: 0.2, engine: "Apple Speech", appName: app, corrections: 1)
    }

    @Test func paroleAlMinutoEConteggi() {
        let s = UsageStats(transcripts: [t(0), t(0)], calendar: cal, now: now)   // 20 parole in 12 s
        #expect(s.totalWords == 20)
        #expect(s.wordsPerMinute == 100)
        #expect(s.corrections == 2)
    }

    @Test func serieCorrenteERecord() {
        // oggi, ieri, l'altro ieri, poi un buco, poi 4 giorni di fila
        let items = [0, 1, 2, 5, 6, 7, 8].map { t($0) }
        let s = UsageStats(transcripts: items, calendar: cal, now: now)
        #expect(s.currentStreak == 3)
        #expect(s.longestStreak == 4)
    }

    @Test func laSerieContaAncheSeOggiNonHaiDettato() {
        let s = UsageStats(transcripts: [t(1), t(2)], calendar: cal, now: now)
        #expect(s.currentStreak == 2)
    }

    @Test func appOrdinatePerParole() {
        let s = UsageStats(transcripts: [t(0, words: 5, app: "Note"), t(0, words: 30, app: "Mail")], calendar: cal, now: now)
        #expect(s.apps.map(\.name) == ["Mail", "Note"])
    }

    @Test func nessunDato() {
        let s = UsageStats(transcripts: [], calendar: cal, now: now)
        #expect(s.wordsPerMinute == 0 && s.currentStreak == 0 && s.monthTrend == nil)
    }
}
