import CoreGraphics
import SwiftUI

/// Il marchio di Dillo: il pettirosso disegnato in Affinity (Branding/Robin.svg).
/// I tracciati sono copiati tali e quali dall'SVG (viewBox 640×512) e disegnati in vettoriale,
/// così lo stesso disegno serve per la barra dei menu, l'indicatore flottante e l'interfaccia.
enum RobinMark {
    static let viewBox = CGSize(width: 640, height: 512)
    /// Proporzione larghezza/altezza della tavola (pettirosso + spazio per le onde).
    static let aspect = viewBox.width / viewBox.height

    // Tracciati da Branding/Robin.svg — se aggiorni il file in Affinity, ricopia qui gli attributi `d`.
    static let beak = SVGPath.parse("M407.004,109.73l91.188,18.575c4.565,0.93 8.207,4.368 9.399,8.871c1.192,4.503 -0.272,9.293 -3.779,12.359l-55.869,48.857c-0.214,-0.977 -0.434,-1.953 -0.66,-2.925c-7.347,-31.605 -21.283,-60.693 -40.28,-85.737Z")
    static let breast = SVGPath.parse("M458.162,207.238c3.433,15.711 5.243,32.027 5.243,48.762c0,125.672 -102.03,227.702 -227.702,227.702c-43.263,0 -83.724,-12.092 -118.185,-33.077c29.781,-141.653 155.559,-248.141 306.014,-248.141c4.085,0 8.153,0.079 12.2,0.234c7.324,0.282 14.584,0.816 21.771,1.594c0.226,0.973 0.446,1.948 0.66,2.925Z")
    static let body = SVGPath.parse("M117.517,450.626c-65.643,-39.973 -109.517,-112.216 -109.517,-194.626c0,-125.672 102.03,-227.702 227.702,-227.702c74.069,0 139.925,35.442 181.52,90.278c18.996,25.043 32.933,54.132 40.28,85.737c-7.187,-0.778 -14.447,-1.312 -21.771,-1.594c-4.048,-0.156 -8.115,-0.234 -12.2,-0.234c-150.454,0 -276.233,106.488 -306.014,248.141Z")
    static let eye = CGPath(ellipseIn: CGRect(x: 314.595 - 28.332, y: 130.082 - 28.332, width: 56.664, height: 56.664), transform: nil)
    static let waves = [
        SVGPath.parse("M497.594,93.887c23.99,-0.948 44.236,17.758 45.184,41.748c0.433,10.961 -3.237,21.141 -9.639,29.055"),
        SVGPath.parse("M497.594,62.058c37.338,-7.029 73.359,17.578 80.389,54.916c3.212,17.06 -0.181,33.845 -8.375,47.716"),
        SVGPath.parse("M498.591,25.453c53.214,-10.018 104.551,25.052 114.569,78.266c4.577,24.314 -0.258,48.236 -11.936,68.004"),
    ]
    static let waveWidth: CGFloat = 20.83

    struct Palette {
        var body: CGColor
        var accent: CGColor      // petto, becco, onde
        var eye: CGColor

        static let brand = Palette(
            body: CGColor(srgbRed: 0.180, green: 0.176, blue: 0.180, alpha: 1),     // #2E2D2E
            accent: CGColor(srgbRed: 0.992, green: 0.384, blue: 0.282, alpha: 1),   // #FD6248
            eye: CGColor(gray: 1, alpha: 1))
    }

    enum Style {
        /// Colori del marchio.
        case color(Palette)
        /// Sagoma monocromatica per la barra dei menu: petto e occhio ritagliati, contorno del petto.
        case template(CGColor)
    }

    /// Disegna il pettirosso adattando la tavola 640×512 dentro `rect` (allineata a sinistra, centrata in verticale).
    /// - waves: intensità 0…1 dei tre archi (vuoto = nascosti).
    /// - waveBoost: moltiplicatore dello spessore delle onde, per renderle leggibili in piccolo.
    static func draw(in ctx: CGContext, rect: CGRect, style: Style = .color(.brand),
                     waves intensities: [CGFloat] = [], waveBoost: CGFloat = 1) {
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.midY - viewBox.height * scale / 2)
        ctx.scaleBy(x: scale, y: scale)

        switch style {
        case .color(let palette):
            ctx.addPath(beak); ctx.setFillColor(palette.accent); ctx.fillPath()
            ctx.addPath(body); ctx.setFillColor(palette.body); ctx.fillPath()
            ctx.addPath(breast); ctx.setFillColor(palette.accent); ctx.fillPath()
            // Occhio trasparente (alpha 0) = ritagliato, utile sulla barra dei menu traslucida.
            if palette.eye.alpha == 0 { ctx.setBlendMode(.clear) }
            ctx.addPath(eye); ctx.setFillColor(palette.eye); ctx.fillPath()
            ctx.setBlendMode(.normal)
            strokeWaves(ctx, color: palette.accent, intensities: intensities, boost: waveBoost)
        case .template(let ink):
            ctx.addPath(beak); ctx.addPath(body); ctx.setFillColor(ink); ctx.fillPath()
            // Contorno del petto: spessore costante in punti (~1.4 pt) a prescindere dalla scala.
            ctx.addPath(breast); ctx.setStrokeColor(ink); ctx.setLineWidth(1.4 / scale); ctx.strokePath()
            ctx.setBlendMode(.clear)
            ctx.addPath(eye); ctx.fillPath()
            ctx.setBlendMode(.normal)
            strokeWaves(ctx, color: ink, intensities: intensities, boost: waveBoost)
        }
        ctx.restoreGState()
    }

    private static func strokeWaves(_ ctx: CGContext, color: CGColor, intensities: [CGFloat], boost: CGFloat) {
        for (i, path) in waves.enumerated() where i < intensities.count && intensities[i] > 0.01 {
            ctx.addPath(path)
            ctx.setStrokeColor(color.copy(alpha: color.alpha * min(intensities[i], 1)) ?? color)
            ctx.setLineWidth(waveWidth * boost)
            ctx.setLineCap(.round)
            ctx.strokePath()
        }
    }
}

/// Il pettirosso come vista SwiftUI (proporzione 640:512), con onde animabili.
struct RobinView: View {
    var waves: [CGFloat] = []
    var waveBoost: CGFloat = 1
    var body: some View {
        Canvas { context, size in
            context.withCGContext { cg in
                RobinMark.draw(in: cg, rect: CGRect(origin: .zero, size: size), waves: waves, waveBoost: waveBoost)
            }
        }
        .aspectRatio(RobinMark.aspect, contentMode: .fit)
    }
}
