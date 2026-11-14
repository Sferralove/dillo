import Testing
@testable import Dillo

@Suite("Dizionario")
struct VocabularyTests {
    let entries = [VocabularyEntry(term: "Claude Code", variants: ["cloud code", "clod code"]),
                   VocabularyEntry(term: "SwiftUI", variants: ["swift ui"])]

    @Test func sostituisceLeVarianti() {
        let (text, n) = VocabularyProcessor.apply("Apri cloud code e scrivi in swift ui.", entries: entries)
        #expect(text == "Apri Claude Code e scrivi in SwiftUI.")
        #expect(n == 2)
    }

    @Test func correggeLeMaiuscoleDelTermine() {
        let (text, n) = VocabularyProcessor.apply("uso swiftui ogni giorno", entries: entries)
        #expect(text == "uso SwiftUI ogni giorno")
        #expect(n == 1)
    }

    @Test func nonToccaLeParoleParziali() {
        let (text, n) = VocabularyProcessor.apply("cloud codex non è una variante", entries: entries)
        #expect(text == "cloud codex non è una variante")
        #expect(n == 0)
    }

    @Test func termineGiaCorrettoNonContaComeCorrezione() {
        let (_, n) = VocabularyProcessor.apply("Claude Code è pronto", entries: entries)
        #expect(n == 0)
    }

    @Test func caratteriSpecialiNelTermine() {
        let e = [VocabularyEntry(term: "C++", variants: ["c plus plus"])]
        #expect(VocabularyProcessor.apply("scrivo in c plus plus", entries: e).text == "scrivo in C++")
    }
    @Test func normalizzaVariantiSenzaDuplicatiOVociVuote() {
        #expect(DictionaryEntry.normalizedVariants(" cloud code, , CLOUD CODE,\n clod code ,") == "cloud code, clod code")
        #expect(DictionaryEntry.normalizedVariants(" , ") == "")
    }

}
