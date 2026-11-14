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

@Suite("Heatmap annuale")
struct ActivityYearTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    @Test(arguments: [2023, 2024, 2026, 2028, 2040])
    func copreOgniGiornoSenzaDuplicati(year: Int) {
        let model = ActivityYear(year: year, calendar: cal)
        let dates = model.weeks.flatMap { $0 }.filter { model.contains($0) }
        let expected = cal.range(of: .day, in: .year, for: model.start)!.count
        #expect(dates.count == expected)
        #expect(Set(dates).count == expected)
        #expect(dates.first == model.start)
        #expect(dates.last == cal.date(byAdding: .day, value: -1, to: model.end))
        #expect(model.months.count == 12)
        #expect(cal.component(.month, from: model.months.last!) == 12)
    }

    @Test(arguments: [2023, 2024, 2026, 2028, 2040])
    func setteRigheDaLunediADomenica(year: Int) {
        let model = ActivityYear(year: year, calendar: cal)
        for week in model.weeks {
            #expect(week.count == 7)
            #expect(cal.component(.weekday, from: week[0]) == 2)
            #expect(cal.component(.weekday, from: week[6]) == 1)
        }
        for month in model.months {
            #expect(model.weeks[model.column(for: month)].contains(month))
        }
    }
}
