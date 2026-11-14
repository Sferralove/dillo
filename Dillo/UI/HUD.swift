import AppKit
import SwiftUI

/// Pannello flottante in basso al centro, non ruba il focus all'app in cui stai scrivendo.
@MainActor
final class HUDController {
    private let panel: NSPanel
    private unowned let controller: DictationController

    init(controller: DictationController) {
        self.controller = controller
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 140),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: HUDView(controller: controller))
    }

    func update() {
        guard controller.showHUD else { panel.orderOut(nil); return }
        switch controller.state {
        case .recording, .transcribing: show()
        default: panel.orderOut(nil)
        }
    }

    private func show() {
        guard !panel.isVisible else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - panel.frame.width / 2, y: f.minY + 12))
        }
        panel.orderFrontRegardless()
    }
}

struct HUDView: View {
    let controller: DictationController
    @State private var history: [Float] = Array(repeating: 0, count: 14)

    private var preview: String {
        controller.state == .recording ? controller.partialText : ""
    }

    var body: some View {
        VStack(spacing: 8) {
            if !preview.isEmpty {
                RevealText(text: preview)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .truncationMode(.head)          // mostra la parte finale, quella che stai dicendo
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            statusRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, preview.isEmpty ? 0 : 10)
        .frame(minHeight: 40)
        .background(Theme.graphite.opacity(0.94), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.10)))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .animation(.spring(duration: 0.35), value: preview.isEmpty)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 12)
        .onChange(of: controller.level) { _, new in
            history.removeFirst()
            history.append(new)
        }
    }

    @ViewBuilder private var statusRow: some View {
        HStack(spacing: 10) {
            if controller.state == .transcribing {
                HUDRobin(level: 0, busy: true)
                Text("Trascrivo…").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            } else if controller.micSilent {
                Image(systemName: "mic.slash.fill").foregroundStyle(Theme.coral)
                Text("Il microfono non sente nulla").font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                HUDRobin(level: controller.level, busy: false)
                HStack(spacing: 3) {
                    ForEach(history.indices, id: \.self) { i in
                        Capsule().fill(Theme.barGradient)
                            .frame(width: 3, height: 4 + CGFloat(history[i]) * 20)
                    }
                }
                .animation(.easeOut(duration: 0.08), value: history)
            }
        }
        .frame(height: 40)
    }
}

/// Il pettirosso dell'indicatore: le onde seguono la voce, o pulsano mentre trascrive.
struct HUDRobin: View {
    var level: Float
    var busy: Bool
    @State private var smoothed: [CGFloat] = [0, 0, 0]

    var body: some View {
        TimelineView(.animation(paused: !busy)) { ctx in
            let waves: [CGFloat] = busy
                ? (0..<3).map { i in CGFloat(max(0, sin(ctx.date.timeIntervalSinceReferenceDate * 4.5 - Double(i) * 0.9))) }
                : smoothed
            RobinView(waves: waves, waveBoost: 1.35)
        }
        .frame(width: 40, height: 32)
        .onChange(of: level) { _, new in
            let l = CGFloat(new) * 2.4
            let targets = [min(max(l, 0), 1), min(max(l - 0.6, 0), 1), min(max(l - 1.2, 0), 1)]
            smoothed = zip(smoothed, targets).map { old, t in old + (t - old) * (t > old ? 0.7 : 0.3) }
        }
    }
}
