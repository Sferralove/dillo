import SwiftUI

/// Testo live che non "sfarfalla": le parole già visibili restano ferme,
/// solo quelle nuove compaiono con una dissolvenza morbida (opacità + sfocatura + leggero sollevamento).
struct RevealText: View {
    let text: String
    var duration: Double = 0.45
    @State private var words: [RevealWord] = []

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { ctx in
            words.reduce(Text("")) { acc, w in
                Text("\(acc)\(Text(w.text + " ").customAttribute(RevealAttribute(start: w.start)))")
            }
            .textRenderer(RevealRenderer(now: ctx.date, duration: duration))
        }
        .onAppear { update(text) }
        .onChange(of: text) { _, new in update(new) }
    }

    private var isAnimating: Bool {
        guard let newest = words.map(\.start).max() else { return false }
        return Date.now.timeIntervalSince(newest) < duration + 0.1
    }

    private func update(_ new: String) {
        words = RevealAligner.align(previous: words, text: new, now: .now)
    }
}

/// Allinea le parole nuove a quelle già mostrate e fa ripartire la dissolvenza solo per quelle davvero nuove.
///
/// Il confronto ignora maiuscole e punteggiatura ("domani" ≈ "domani,") e tollera che l'inizio del testo
/// cambi o scompaia (finestra scorrevole di Parakeet, frasi finalizzate da Apple): ogni parola viene cercata
/// più avanti nell'elenco precedente invece che alla stessa posizione, così una piccola revisione
/// non fa ripartire l'animazione di tutte le parole successive.
enum RevealAligner {
    static func align(previous words: [RevealWord], text new: String, now: Date) -> [RevealWord] {
        let tokens = new.split(whereSeparator: \.isWhitespace).map(String.init)
        let old = words.map { normalize($0.text) }
        var result: [RevealWord] = []
        var cursor = 0
        for token in tokens {
            let key = normalize(token)
            // All'inizio cerca in tutto il testo precedente (l'inizio può essere sparito), poi in una finestra breve.
            let limit = result.isEmpty ? old.count : min(old.count, cursor + 6)
            if cursor < limit, let j = (cursor..<limit).first(where: { old[$0] == key || isRevision(old[$0], key) }) {
                result.append(RevealWord(text: token, start: words[j].start))
                cursor = j + 1
            } else {
                result.append(RevealWord(text: token, start: now))
            }
        }
        return result
    }

    static func normalize(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }

    /// Parola ancora in corso di riconoscimento (es. "dett" → "dettatura").
    static func isRevision(_ a: String, _ b: String) -> Bool {
        min(a.count, b.count) >= 3 && (a.hasPrefix(b) || b.hasPrefix(a))
    }
}

struct RevealWord: Equatable {
    let text: String
    let start: Date
}

private struct RevealAttribute: TextAttribute {
    let start: Date
}

private struct RevealRenderer: TextRenderer {
    var now: Date
    var duration: Double

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let attr = run[RevealAttribute.self] else { ctx.draw(run); continue }
                let t = min(max(now.timeIntervalSince(attr.start) / duration, 0), 1)
                let eased = 1 - pow(1 - t, 3)                 // easeOutCubic
                guard eased < 1 else { ctx.draw(run); continue }
                var c = ctx
                c.opacity = eased
                c.addFilter(.blur(radius: (1 - eased) * 5))
                c.translateBy(x: 0, y: (1 - eased) * 3)
                c.draw(run)
            }
        }
    }
}
