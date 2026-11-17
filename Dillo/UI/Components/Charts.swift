import AppKit
import SwiftUI

/// Contenitore delle card della Panoramica.
struct StatCard<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: () -> Content
    @State private var hover = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(hover ? Theme.accent.opacity(0.3) : Theme.stroke))
            .shadow(color: .black.opacity(hover ? 0.10 : 0), radius: 14, y: 6)
            .scaleEffect(hover && !reduceMotion ? 1.004 : 1)
            .onHover { hover = $0 }
            .animation(reduceMotion ? nil : Theme.interaction, value: hover)
    }
}

/// Entrata morbida a cascata: dissolvenza e piccolo scatto verso l'alto, ritardati per indice.
struct RevealModifier: ViewModifier {
    var index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                withAnimation(.spring(duration: 0.65, bounce: 0.12).delay(0.04 + Double(index) * 0.07)) { shown = true }
            }
    }
}

extension View {
    func reveal(_ index: Int = 0) -> some View { modifier(RevealModifier(index: index)) }
}

/// Numero che conta da zero al valore (e segue le variazioni successive).
struct CountingText: View {
    let value: Int
    var duration = 1.1
    @State private var shown = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Counter(value: reduceMotion ? Double(value) : shown)
            .onAppear { if !reduceMotion { withAnimation(.easeOut(duration: duration).delay(0.15)) { shown = Double(value) } } }
            .onChange(of: value) { _, new in withAnimation(.easeOut(duration: 0.5)) { shown = Double(new) } }
    }

    private struct Counter: View, Animatable {
        var value: Double
        var animatableData: Double { get { value } set { value = newValue } }
        var body: some View { Text(Int(value.rounded()).formatted()).monospacedDigit() }
    }
}

/// Semicerchio spesso con la velocità di dettatura rispetto alla tastiera.
struct SpeedGauge: View {
    let wpm: Int
    var maxWPM = 220.0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = shown || reduceMotion ? min(Double(wpm) / maxWPM, 1) : 0
        ZStack {
            Arc().stroke(Theme.accentScale[0], style: StrokeStyle(lineWidth: 18, lineCap: .round))
            Arc().trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 18, lineCap: .round))
            VStack(spacing: 2) {
                Text(wpm > 0 ? String(format: "%.1f×", Double(wpm) / UsageStats.typingWPM) : "—")
                    .font(.system(size: 22, weight: .regular))
                Text("la tastiera").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            .offset(y: 14)
        }
        .frame(width: 200, height: 104)
        .animation(reduceMotion ? nil : .spring(duration: 1.1, bounce: 0.1), value: progress)
        .onAppear { withAnimation(.spring(duration: 1.1, bounce: 0.1).delay(0.35)) { shown = true } }
    }

    private nonisolated struct Arc: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2 - 9,
                     startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            return p
        }
    }
}

/// Barra orizzontale con percentuale interna; `scale` è la frazione che occupa tutta la larghezza.
struct ProportionBar: View {
    let fraction: Double
    var scale = 1.0
    let color: Color
    var height: CGFloat = 36
    var index = 0
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let target = max(geo.size.width * min(fraction / max(scale, 0.0001), 1), 44)
            let w = grown || reduceMotion ? target : 8
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: w)
                .overlay {
                    Text(fraction < 0.01 ? "<1%" : "\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                        .opacity(grown || reduceMotion ? 1 : 0)
                }
                .animation(reduceMotion ? nil : .spring(duration: 0.9, bounce: 0.1), value: target)
        }
        .frame(height: height)
        .onAppear { withAnimation(.spring(duration: 0.9, bounce: 0.1).delay(0.35 + Double(index) * 0.08)) { grown = true } }
    }
}

/// Icona dell'app dal bundle identifier, con fallback a un simbolo.
struct AppIcon: View {
    let bundleID: String?
    var size: CGFloat = 22

    var body: some View {
        if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: size, height: size)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: size * 0.75))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: size, height: size)
        }
    }
}

/// Heatmap dell'attività: sette righe (lun–dom), finestra di 18 settimane con paginazione all'indietro.
struct ActivityHeatmap: View {
    let daily: [Date: Int]
    let streak: Int
    let longest: Int
    @State private var pageBack = 0
    @State private var availableWidth: CGFloat = 0
    private let gap: CGFloat = 4
    private let labelWidth: CGFloat = 34
    private let columns = 18

    private var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }

    var body: some View {
        let cal = calendar
        let today = cal.startOfDay(for: .now)
        let thisMonday = cal.dateInterval(of: .weekOfYear, for: today)!.start
        let firstMonday = cal.date(byAdding: .weekOfYear, value: -(columns - 1) - pageBack * columns, to: thisMonday)!
        let weeks: [Date] = (0..<columns).map { cal.date(byAdding: .weekOfYear, value: $0, to: firstMonday)! }
        let values = daily.values.filter { $0 > 0 }.sorted()
        let thresholds = [0.25, 0.5, 0.75].map { q in values.isEmpty ? 1 : values[min(values.count - 1, Int(Double(values.count) * q))] }
        let streakDays = currentStreakDays(today: today, cal: cal)
        let cell = min(20, max(9, (availableWidth - labelWidth - 8 + gap) / CGFloat(columns) - gap))

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(streak == 1 ? "1 giorno di fila" : "\(streak) giorni di fila").font(Typo.display(30))
                Spacer(minLength: 8)
                Eyebrow("Serie più lunga | \(longest) giorni")
            }
            HStack {
                Button { withAnimation(.snappy) { pageBack += 1 } } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).help("Settimane precedenti")
                    .disabled(weeks[0] < (daily.keys.min() ?? today).addingTimeInterval(-86400 * 7 * 18))
                Spacer()
                Button { withAnimation(.snappy) { pageBack = max(0, pageBack - 1) } } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain).disabled(pageBack == 0).help("Settimane successive")
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: gap) {
                    Color.clear.frame(height: 20)
                    ForEach(0..<7, id: \.self) { index in
                        Text(cal.shortWeekdaySymbols[(index + 1) % 7].capitalized)
                            .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                            .frame(height: cell)
                    }
                }
                .frame(width: labelWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: gap) {
                    ZStack(alignment: .topLeading) {
                        Color.clear
                        ForEach(Array(weeks.enumerated()), id: \.offset) { i, week in
                            if i == 0 || cal.component(.month, from: week) != cal.component(.month, from: weeks[i - 1]) {
                                Text(week.formatted(.dateTime.month(.abbreviated)).capitalized)
                                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                                    .fixedSize().offset(x: CGFloat(i) * (cell + gap))
                            }
                        }
                    }
                    .frame(height: 20)
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(weeks, id: \.self) { week in
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { d in
                                    let day = cal.date(byAdding: .day, value: d, to: week)!
                                    dayCell(day, today: today, thresholds: thresholds, cell: cell, inStreak: streakDays.contains(day))
                                        .modifier(CellReveal(column: weekIndex(week, in: weeks), row: d))
                                }
                            }
                        }
                    }
                    .id(pageBack)
                    .transition(.opacity)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }

            HStack(spacing: 6) {
                Text("Più")
                ForEach(Array(Theme.accentScale.reversed().enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: 4).fill(c).frame(width: 16, height: 16)
                }
                Text("Meno")
                Spacer(minLength: 8)
                RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.accent, lineWidth: 1.5).frame(width: 20, height: 20)
                Text("Serie attuale")
            }
            .font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
        }
    }

    private func weekIndex(_ week: Date, in weeks: [Date]) -> Int { weeks.firstIndex(of: week) ?? 0 }

    private func currentStreakDays(today: Date, cal: Calendar) -> Set<Date> {
        guard streak > 0 else { return [] }
        let end = (daily[today] ?? 0) > 0 ? today : cal.date(byAdding: .day, value: -1, to: today)!
        return Set((0..<streak).compactMap { cal.date(byAdding: .day, value: -$0, to: end) })
    }

    private func dayCell(_ day: Date, today: Date, thresholds: [Int], cell: CGFloat, inStreak: Bool) -> some View {
        let future = day > today
        let words = daily[day] ?? 0
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(future ? Color.clear : color(words, thresholds))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(inStreak ? Theme.accent : Color.clear, lineWidth: 1.5))
            .frame(width: cell, height: cell)
            .help(future ? "" : "\(day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())) · \(words.formatted()) parole")
            .accessibilityLabel(future ? "" : "\(day.formatted(.dateTime.day().month(.wide))): \(words) parole")
    }

    private func color(_ words: Int, _ th: [Int]) -> Color {
        guard words > 0 else { return Theme.empty }
        if words <= th[0] { return Theme.accentScale[0] }
        if words <= th[1] { return Theme.accentScale[1] }
        if words <= th[2] { return Theme.accentScale[2] }
        return Theme.accentScale[3]
    }
}

/// Le celle della heatmap compaiono a onda, colonna dopo colonna.
private struct CellReveal: ViewModifier {
    let column: Int, row: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.3)
            .opacity(shown || reduceMotion ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.45, bounce: 0.25).delay(0.5 + Double(column) * 0.025 + Double(row) * 0.01)) { shown = true }
            }
    }
}
