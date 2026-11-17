import AppKit
import Observation
import SwiftUI

/// Icona della barra dei menu: la "D" di Dillo.
/// A riposo è una sagoma monocromatica (template); mentre detti le tre righe di testo diventano corallo
/// e si accendono seguendo la voce; mentre trascrive pulsano in sequenza.
@MainActor
@Observable
final class MenuBarIconModel {
    private(set) var image: NSImage = MenuBarIconModel.render(mode: .idle, waves: [])

    private var waves: [CGFloat] = [0, 0, 0]
    private var pulse: Task<Void, Never>?
    private var mode: Mode = .idle

    enum Mode: Equatable { case idle, recording, busy, error }

    func set(mode new: Mode) {
        guard new != mode else { return }
        mode = new
        pulse?.cancel()
        waves = [0, 0, 0]
        switch new {
        case .idle, .error, .recording:
            image = Self.render(mode: new, waves: waves)
        case .busy:
            pulse = Task { [weak self] in
                var phase = 0.0
                while !Task.isCancelled {
                    phase += 0.28
                    let w = (0..<3).map { i in CGFloat(max(0, sin(phase - Double(i) * 0.9))) }
                    self?.image = Self.render(mode: .busy, waves: w)
                    try? await Task.sleep(for: .milliseconds(70))
                }
            }
        }
    }

    /// Nuovo livello audio (0...1): più forte parli, più onde si accendono.
    func push(level: Float) {
        guard mode == .recording else { return }
        let l = CGFloat(level) * 2.4
        let targets = [min(max(l, 0), 1), min(max(l - 0.6, 0), 1), min(max(l - 1.2, 0), 1)]
        waves = zip(waves, targets).map { old, t in old + (t - old) * (t > old ? 0.7 : 0.3) }   // attacco rapido, rilascio morbido
        image = Self.render(mode: .recording, waves: waves)
    }

    /// Marchio alto 16 pt (≈ 21 pt di larghezza).
    static func render(mode: Mode, waves: [CGFloat]) -> NSImage {
        let size = NSSize(width: 16 * LogoMark.aspect, height: 16)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            switch mode {
            case .idle, .error:
                let ink = CGColor(gray: 0, alpha: mode == .error ? 0.45 : 1)
                LogoMark.draw(in: ctx, rect: rect, palette: .init(ink: ink, accent: ink))
            case .recording, .busy:
                // "D" e scie seguono il colore del testo della barra dei menu (chiaro/scuro); le righe sono corallo.
                let palette = LogoMark.Palette(ink: NSColor.labelColor.cgColor, accent: LogoMark.Palette.brand.accent)
                LogoMark.draw(in: ctx, rect: rect, palette: palette, lines: waves)
            }
            return true
        }
        image.isTemplate = (mode == .idle || mode == .error)
        image.accessibilityDescription = "Dillo"
        return image
    }
}
