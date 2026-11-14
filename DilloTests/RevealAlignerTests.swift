import Foundation
import Testing
@testable import Dillo

@Suite("Comparsa delle parole")
struct RevealAlignerTests {
    let t0 = Date(timeIntervalSince1970: 0)
    let t1 = Date(timeIntervalSince1970: 10)

    @Test func paroleEsistentiRestanoFerme() {
        let first = RevealAligner.align(previous: [], text: "ciao come stai", now: t0)
        let next = RevealAligner.align(previous: first, text: "ciao come stai oggi", now: t1)
        #expect(next.map(\.start) == [t0, t0, t0, t1])
    }

    @Test func punteggiaturaEMaiuscoleNonFannoRipartire() {
        let first = RevealAligner.align(previous: [], text: "ciao domani ci vediamo", now: t0)
        let next = RevealAligner.align(previous: first, text: "Ciao, domani ci vediamo.", now: t1)
        #expect(next.allSatisfy { $0.start == t0 })
    }

    @Test func inizioScomparsoNonFaRipartireIlResto() {
        let first = RevealAligner.align(previous: [], text: "uno due tre quattro cinque", now: t0)
        let next = RevealAligner.align(previous: first, text: "tre quattro cinque sei", now: t1)
        #expect(next.map(\.start) == [t0, t0, t0, t1])
    }

    @Test func parolaInCorsoMantieneLaComparsa() {
        let first = RevealAligner.align(previous: [], text: "la dett", now: t0)
        let next = RevealAligner.align(previous: first, text: "la dettatura", now: t1)
        #expect(next.map(\.start) == [t0, t0])
    }
}
