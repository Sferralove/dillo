import AppKit
import SwiftUI

/// Contenitore delle card della Panoramica.
struct StatCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(Theme.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.09)))
    }
}

/// Semicerchio con la velocità di dettatura rispetto alla tastiera.
struct SpeedGauge: View {
    let wpm: Int
    var maxWPM = 220.0

    var body: some View {
        let progress = min(Double(wpm) / maxWPM, 1)
        ZStack {
            Arc().stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            Arc().trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [Theme.coralSoft, Theme.coral], center: .bottom,
                                        startAngle: .degrees(180), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
            // Tacca della velocità media di battitura
            Arc().trim(from: UsageStats.typingWPM / maxWPM - 0.004, to: UsageStats.typingWPM / maxWPM + 0.004)
                .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 16))
            VStack(spacing: 2) {
                Text(wpm > 0 ? String(format: "%.1f×", Double(wpm) / UsageStats.typingWPM) : "—")
                    .font(Typo.display(20))
                Text("la tastiera").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            }
            .offset(y: 10)
        }
        .frame(width: 128, height: 72)
        .animation(.spring(duration: 0.8), value: wpm)
    }

    private nonisolated struct Arc: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2 - 8,
                     startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            return p
        }
    }
}

/// Barra orizzontale proporzionale con etichetta interna.
struct ProportionBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width * fraction, 44)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: w)
                .overlay(alignment: .leading) {
                    Text(fraction < 0.01 ? "<1%" : "\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(fraction > 0.3 ? .white : .white.opacity(0.9))
                        .padding(.leading, 10)
                }
        }
        .frame(height: height)
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

/// Heatmap stile GitHub: sette righe e l'intero anno, gennaio–dicembre.
struct ActivityHeatmap: View {
    let daily: [Date: Int]
    let streak: Int
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var hovered: Date?
    @State private var selected: Date?
    @State private var availableWidth: CGFloat = 0
    private let gap: CGFloat = 2
    private let labelWidth: CGFloat = 34

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var firstYear: Int { min(currentYear, daily.keys.map { Calendar.current.component(.year, from: $0) }.min() ?? currentYear) }

    var body: some View {
        let model = ActivityYear(year: year)
        let today = model.calendar.startOfDay(for: .now)
        let values = daily.filter { model.contains($0.key) && $0.key <= today }.values.filter { $0 > 0 }.sorted()
        let thresholds = [0.25, 0.5, 0.75].map { q in values.isEmpty ? 1 : values[min(values.count - 1, Int(Double(values.count) * q))] }
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(streak == 1 ? "1 giorno di fila" : "\(streak) giorni di fila")
                    .font(Typo.display(24))
                Spacer(minLength: 0)
                Picker("Anno", selection: $year) {
                    ForEach(Array((firstYear...currentYear).reversed()), id: \.self) { y in Text(String(y)).tag(y) }
                }
                .labelsHidden().fixedSize().accessibilityLabel("Anno del grafico attività")
            }
            let cell = min(16, max(10, (availableWidth - labelWidth - 8 + gap) / CGFloat(model.weeks.count) - gap))
            let gridWidth = CGFloat(model.weeks.count) * (cell + gap) - gap + labelWidth + 8
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: gap) {
                            Color.clear.frame(height: 20)
                            ForEach(0..<7, id: \.self) { index in
                                Text(model.calendar.shortWeekdaySymbols[(index + 1) % 7].capitalized)
                                    .font(.system(size: 10.5)).foregroundStyle(Theme.textSecondary)
                                    .frame(height: cell)
                            }
                        }
                        .frame(width: labelWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: gap) {
                            ZStack(alignment: .topLeading) {
                                Color.clear
                                ForEach(model.months, id: \.self) { month in
                                    Text(month.formatted(.dateTime.month(.abbreviated)).capitalized)
                                        .font(.system(size: 10.5)).foregroundStyle(Theme.textSecondary)
                                        .fixedSize()
                                        .offset(x: CGFloat(model.column(for: month)) * (cell + gap))
                                }
                            }
                            .frame(width: CGFloat(model.weeks.count) * (cell + gap) - gap, height: 20)
                            HStack(alignment: .top, spacing: gap) {
                                ForEach(model.weeks.indices, id: \.self) { week in
                                    VStack(spacing: gap) {
                                        ForEach(model.weeks[week], id: \.self) { day in
                                            dayCell(day, model: model, today: today, thresholds: thresholds, cell: cell)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.automatic)
                .defaultScrollAnchor(.trailing)
                if availableWidth > 0 && gridWidth > availableWidth + 0.5 {
                    Label("Scorri per vedere gli altri mesi", systemImage: "arrow.left.and.right")
                        .font(.system(size: 10.5)).foregroundStyle(Theme.textSecondary)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { legend; Spacer(minLength: 0); detail(model: model, today: today) }
                VStack(alignment: .leading, spacing: 10) { legend; detail(model: model, today: today) }
            }
        }
        .onChange(of: year) { hovered = nil; selected = nil }
    }

    private func dayCell(_ day: Date, model: ActivityYear, today: Date, thresholds: [Int], cell: CGFloat) -> some View {
        let inYear = model.contains(day)
        let future = day > today
        let words = daily[day] ?? 0
        return Button { selected = day } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(!inYear ? Color.clear : future ? Color.white.opacity(0.025) : color(words, thresholds))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(inYear && (day == today || selected == day) ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1))
                .frame(width: cell, height: cell)
        }
        .buttonStyle(.plain)
        .disabled(!inYear || future)
        .accessibilityHidden(!inYear)
        .accessibilityLabel(description(day, today: today))
        .help(description(day, today: today))
        .onHover { on in hovered = on && inYear ? day : nil }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Meno")
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3).fill(i == 0 ? Color.white.opacity(0.05) : Theme.coralScale[i - 1])
                    .frame(width: 11, height: 11)
            }
            Text("Più parole")
        }
        .font(.system(size: 10.5)).foregroundStyle(Theme.textSecondary)
    }

    private func detail(model: ActivityYear, today: Date) -> some View {
        Text((hovered ?? selected).map { description($0, today: today) } ?? "")
            .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
    }

    private func description(_ day: Date, today: Date) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        return day > today ? "\(date) · giorno futuro" : "\(date) · \((daily[day] ?? 0).formatted()) parole"
    }

    private func color(_ words: Int, _ th: [Int]) -> Color {
        guard words > 0 else { return Color.white.opacity(0.05) }
        if words <= th[0] { return Theme.coralScale[0] }
        if words <= th[1] { return Theme.coralScale[1] }
        if words <= th[2] { return Theme.coralScale[2] }
        return Theme.coralScale[3]
    }
}
