import Foundation

struct VocabularyEntry: Sendable {
    let term: String
    let variants: [String]
}

/// Applica il dizionario al testo trascritto: sostituisce le varianti errate con la grafia corretta
/// e normalizza maiuscole/minuscole del termine.
enum VocabularyProcessor {
    /// Restituisce il testo corretto e il numero di correzioni effettive (varianti sostituite o maiuscole sistemate).
    static func apply(_ text: String, entries: [VocabularyEntry]) -> (text: String, corrections: Int) {
        var out = text
        var corrections = 0
        for entry in entries {
            for form in entry.variants + [entry.term] where !form.isEmpty {
                let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: form) + "(?![\\p{L}\\p{N}])"
                guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                let ns = out as NSString
                for m in re.matches(in: out, range: NSRange(location: 0, length: ns.length)) where ns.substring(with: m.range) != entry.term {
                    corrections += 1
                }
                out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out),
                                                  withTemplate: NSRegularExpression.escapedTemplate(for: entry.term))
            }
        }
        return (out, corrections)
    }
}
