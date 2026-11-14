import AppKit
import SwiftUI

/// Contenitore delle card della Panoramica.
struct StatCard<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
    }
}

/// Semicerchio con la velocità di dettatura rispetto alla tastiera.
struct SpeedGauge: View {
    let wpm: Int
    var maxWPM = 220.0

    var body: some View {
        let progress = min(Double(wpm) / maxWPM, 1)
        ZStack {
            Arc().stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            Arc().trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [Theme.coralSoft, Theme.coral], center: .bottom,
                                        startAngle: .degrees(180), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
            // Tacca della velocità media di battitura
            Arc().trim(from: UsageStats.typingWPM / maxWPM - 0.004, to: UsageStats.typingWPM / maxWPM + 0.004)
                .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 22))
            VStack(spacing: 2) {
                Text(wpm > 0 ? String(format: "%.1f×", Double(wpm) / UsageStats.typingWPM) : "—")
                    .font(Typo.display(26))
                Text("la tastiera").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
            .offset(y: 18)
        }
        .frame(width: 190, height: 105)
        .animation(.spring(duration: 0.8), value: wpm)
    }

    private struct Arc: Shape {
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

/// Calendario a celle (stile "contributi") con le parole dettate per giorno.
struct ActivityHeatmap: View {
    let daily: [Date: Int]
    var weeks = 22
    var cell: CGFloat = 13
    var gap: CGFloat = 4
    @State private var hovered: Date?

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // lunedì
        return c
    }

    private var columns: [[Date]] {
        let today = cal.startOfDay(for: .now)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)!.start
        let first = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: weekStart)!
        return (0..<weeks).map { w in
            (0..<7).map { d in cal.date(byAdding: .day, value: w * 7 + d, to: first)! }
        }
    }

    private var thresholds: [Int] {
        let values = daily.values.filter { $0 > 0 }.sorted()
        guard !values.isEmpty else { return [1, 2, 3] }
        func q(_ p: Double) -> Int { values[min(values.count - 1, Int(Double(values.count) * p))] }
        return [q(0.25), q(0.5), q(0.75)]
    }

    var body: some View {
        let cols = columns
        let th = thresholds
        let today = cal.startOfDay(for: .now)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .trailing, spacing: gap) {
                    Color.clear.frame(height: 14)
                    ForEach(0..<7, id: \.self) { d in
                        Text(d % 2 == 0 ? weekdayName(d) : "")
                            .font(.system(size: 9.5)).foregroundStyle(Theme.textTertiary)
                            .frame(height: cell)
                    }
                }
                HStack(alignment: .top, spacing: gap) {
                    ForEach(cols.indices, id: \.self) { w in
                        VStack(spacing: gap) {
                            Text(monthLabel(cols, w)).font(.system(size: 9.5)).foregroundStyle(Theme.textTertiary)
                                .fixedSize().frame(width: cell, height: 14, alignment: .leading)
                            ForEach(cols[w], id: \.self) { day in
                                let words = daily[day] ?? 0
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(day > today ? Color.clear : color(words, th))
                                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(day == today ? Color.white.opacity(0.7) : .clear, lineWidth: 1))
                                    .frame(width: cell, height: cell)
                                    .onHover { hovered = $0 ? day : (hovered == day ? nil : hovered) }
                                    .help("\(day.formatted(.dateTime.day().month(.wide))): \(words) parole")
                            }
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Text("Meno").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3).fill(i == 0 ? Color.white.opacity(0.05) : Theme.coralScale[i - 1])
                        .frame(width: 11, height: 11)
                }
                Text("Più").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                Spacer()
                if let hovered {
                    Text("\(hovered.formatted(.dateTime.weekday(.wide).day().month(.wide))) · \(daily[hovered] ?? 0) parole")
                        .font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func color(_ words: Int, _ th: [Int]) -> Color {
        guard words > 0 else { return Color.white.opacity(0.05) }
        if words <= th[0] { return Theme.coralScale[0] }
        if words <= th[1] { return Theme.coralScale[1] }
        if words <= th[2] { return Theme.coralScale[2] }
        return Theme.coralScale[3]
    }

    private func weekdayName(_ index: Int) -> String {
        let symbols = cal.shortWeekdaySymbols // dom, lun, …
        return symbols[(index + 1) % 7].capitalized
    }

    private func monthLabel(_ cols: [[Date]], _ w: Int) -> String {
        let m = cal.component(.month, from: cols[w][0])
        if w == 0 || cal.component(.month, from: cols[w - 1][0]) != m {
            return cols[w][0].formatted(.dateTime.month(.abbreviated)).capitalized
        }
        return ""
    }
}
