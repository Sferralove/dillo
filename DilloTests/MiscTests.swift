import CoreGraphics
import Foundation
import Testing
@testable import Dillo

@Suite("Varie")
struct MiscTests {
    @Test func tracciatoSVGRelativoEAssoluto() {
        let p = SVGPath.parse("M10,10l20,0l0,20L10,30Z")
        #expect(p.boundingBoxOfPath == CGRect(x: 10, y: 10, width: 20, height: 20))
    }

    @Test func tracciatoSVGNumeriCompatti() {
        // "-5-5" e ".5.5" sono due numeri ciascuno
        let p = SVGPath.parse("M0,0l10-5l.5.5")
        #expect(abs(p.currentPoint.x - 10.5) < 0.001 && abs(p.currentPoint.y + 4.5) < 0.001)
    }

    @Test func ilPettirossoStaNellaTavola() {
        let box = RobinMark.body.boundingBoxOfPath.union(RobinMark.beak.boundingBoxOfPath)
        #expect(CGRect(origin: .zero, size: RobinMark.viewBox).contains(box))
    }

    @Test func linguaRiconosciuta() {
        #expect(LanguageDetector.dominantLanguage(of: "Hi, I wanted to confirm the meeting tomorrow at ten with the team", current: "it") == "en")
        #expect(LanguageDetector.dominantLanguage(of: "Ciao, ti confermo la riunione di domani alle dieci con il team", current: "it") == "it")
    }

    @Test func esportazioneCSVConVirgoletteENuoveRighe() {
        let t = Transcript(text: "Ha detto \"ciao\",\npoi è uscito", duration: 3, latency: 0.1, engine: "Apple Speech", appName: "Mail")
        let csv = HistoryExporter.render([t], as: .csv)
        #expect(csv.contains("\"Ha detto \"\"ciao\"\",\npoi è uscito\""))
        #expect(csv.hasPrefix("data,app,parole"))
    }
}
