import Foundation
import SwiftData

@Model
final class Transcript {
    var text: String
    var createdAt: Date
    /// Durata della registrazione in secondi.
    var duration: Double
    /// Secondi tra fine registrazione e testo pronto.
    var latency: Double
    var engine: String
    var appName: String?
    var appBundleID: String?
    /// Parole corrette dal dizionario in questa trascrizione.
    var corrections: Int = 0

    init(text: String, createdAt: Date = .now, duration: Double, latency: Double, engine: String,
         appName: String?, appBundleID: String? = nil, corrections: Int = 0) {
        self.text = text
        self.createdAt = createdAt
        self.duration = duration
        self.latency = latency
        self.engine = engine
        self.appName = appName
        self.appBundleID = appBundleID
        self.corrections = corrections
    }

    var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
}

@Model
final class DictionaryEntry {
    /// Grafia corretta (es. "Claude Code").
    var term: String
    /// Forme sbagliate che il motore produce, separate da virgola (es. "cloud code, clod code").
    var variants: String
    var createdAt: Date

    init(term: String, variants: String = "", createdAt: Date = .now) {
        self.term = term
        self.variants = variants
        self.createdAt = createdAt
    }

    var variantList: [String] {
        variants.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
