import AppKit
import Observation
import SwiftUI

/// Icona della barra dei menu: il pettirosso di Dillo.
/// A riposo è una sagoma monocromatica (template); mentre detti il petto diventa corallo
/// e dal becco escono onde che seguono la voce; mentre trascrive le onde pulsano in sequenza.
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

    /// Tavola 23×18 pt: pettirosso alto 18 pt (≈ 14 pt di corpo) + onde a destra.
    static func render(mode: Mode, waves: [CGFloat]) -> NSImage {
        let size = NSSize(width: 18 * RobinMark.aspect, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            switch mode {
            case .idle, .error:
                RobinMark.draw(in: ctx, rect: rect, style: .template(CGColor(gray: 0, alpha: mode == .error ? 0.45 : 1)))
            case .recording, .busy:
                // Il corpo segue il colore del testo della barra dei menu (chiaro/scuro); petto, becco e onde in corallo.
                var palette = RobinMark.Palette.brand
                palette.body = NSColor.labelColor.cgColor
                palette.eye = CGColor(gray: 0, alpha: 0)     // ritagliato
                // A 18 pt tre onde spesse si fonderebbero: usiamo la prima e la terza (più distanziate),
                // spesse 1.8× rispetto all'SVG (≈ 1.3 pt). La seconda intensità guida l'arco esterno.
                let two: [CGFloat] = [waves.first ?? 0, 0, max(waves.count > 1 ? waves[1] : 0, waves.last ?? 0)]
                RobinMark.draw(in: ctx, rect: rect, style: .color(palette), waves: two, waveBoost: 1.8)
            }
            return true
        }
        image.isTemplate = (mode == .idle || mode == .error)
        image.accessibilityDescription = "Dillo"
        return image
    }
}
