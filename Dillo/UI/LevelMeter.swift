import SwiftUI

/// Forma d'onda a barre che scorre con il livello audio in tempo reale.
struct LevelMeter: View {
    var level: Float
    var active: Bool
    var bars: Int = 32
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 3
    var maxHeight: CGFloat = 36

    @State private var history: [Float] = []

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<bars, id: \.self) { i in
                let v = i < history.count ? history[i] : 0
                Capsule()
                    .fill(active ? AnyShapeStyle(Theme.barGradient) : AnyShapeStyle(Theme.ink.opacity(0.14)))
                    .frame(width: barWidth, height: max(3, CGFloat(v) * maxHeight))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.08), value: history)
        .onAppear { history = Array(repeating: 0, count: bars) }
        .onChange(of: level) { _, new in
            guard !history.isEmpty else { return }
            history.removeFirst()
            history.append(active ? new : 0)
        }
        .onChange(of: active) { _, isActive in
            if !isActive { history = Array(repeating: 0, count: bars) }
        }
        .accessibilityLabel("Livello audio")
    }
}
