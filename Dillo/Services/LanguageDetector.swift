import NaturalLanguage

/// Riconosce la lingua del testo trascritto (on-device, NaturalLanguage).
enum LanguageDetector {
    static let supported: Set<String> = ["it", "en", "es", "fr", "de", "pt"]

    /// Restituisce il codice della lingua dominante solo se il riconoscimento è molto sicuro.
    static func dominantLanguage(of text: String, current: String) -> String? {
        let r = NLLanguageRecognizer()
        r.languageConstraints = supported.map { NLLanguage($0) }
        r.processString(text)
        let hyps = r.languageHypotheses(withMaximum: 2)
        guard let (lang, p) = hyps.max(by: { $0.value < $1.value }), p >= 0.85 else { return nil }
        return lang.rawValue
    }
}
