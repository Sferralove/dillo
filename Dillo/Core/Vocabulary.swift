import Foundation

nonisolated struct VocabularyEntry: Sendable, Equatable {
    let term: String
    let variants: [String]
}

/// Applica il dizionario al testo trascritto: sostituisce le varianti errate con la grafia corretta
/// e normalizza maiuscole/minuscole del termine.
nonisolated enum VocabularyProcessor {
    /// Restituisce il testo corretto e il numero di correzioni effettive (varianti sostituite o maiuscole sistemate).
    static func apply(_ text: String, entries: [VocabularyEntry]) -> (text: String, corrections: Int) {
        CompiledVocabulary(entries).apply(text)
    }
}

/// Dizionario con le espressioni regolari già compilate, da riusare tra una dettatura e l'altra.
nonisolated struct CompiledVocabulary: @unchecked Sendable {   // NSRegularExpression è immutabile e thread-safe
    private struct Rule {
        let regex: NSRegularExpression
        let term: String
        let template: String
    }

    private let rules: [Rule]

    init(_ entries: [VocabularyEntry]) {
        rules = entries.flatMap { entry in
            (entry.variants + [entry.term]).compactMap { form -> Rule? in
                guard !form.isEmpty else { return nil }
                let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: form) + "(?![\\p{L}\\p{N}])"
                guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
                return Rule(regex: re, term: entry.term, template: NSRegularExpression.escapedTemplate(for: entry.term))
            }
        }
    }

    func apply(_ text: String) -> (text: String, corrections: Int) {
        var out = text
        var corrections = 0
        for rule in rules {
            let ns = out as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = rule.regex.matches(in: out, range: range)
            guard !matches.isEmpty else { continue }
            corrections += matches.count { ns.substring(with: $0.range) != rule.term }
            out = rule.regex.stringByReplacingMatches(in: out, range: range, withTemplate: rule.template)
        }
        return (out, corrections)
    }
}
