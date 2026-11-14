import SwiftData
import SwiftUI

/// Dizionario personale: nomi propri, termini tecnici e correzioni automatiche.
struct DictionaryPage: View {
    @Environment(\.modelContext) private var context
    @Environment(DictationController.self) private var controller
    @Query(sort: \DictionaryEntry.term) private var entries: [DictionaryEntry]
    @Query private var transcripts: [Transcript]
    @State private var search = ""
    @State private var term = ""
    @State private var variants = ""
    @FocusState private var termFocused: Bool

    private var filtered: [DictionaryEntry] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        return entries.filter { $0.term.localizedStandardContains(q) || $0.variants.localizedStandardContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Dizionario",
                       subtitle: "\(entries.count) voci · \(transcripts.reduce(0) { $0 + $1.corrections }) correzioni applicate",
                       search: $search, searchPrompt: "Cerca nel dizionario")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    addCard
                    if entries.isEmpty {
                        EmptyState(symbol: "character.book.closed", title: "Insegna a Dillo le tue parole",
                                   text: "Nomi, sigle, marchi e termini tecnici: aggiungili qui e verranno scritti sempre nel modo giusto.")
                            .frame(minHeight: 260)
                    } else if filtered.isEmpty {
                        EmptyState(symbol: "magnifyingglass", title: "Nessun risultato", text: "Nessuna voce contiene “\(search)”.")
                            .frame(minHeight: 200)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                            ForEach(filtered) { entry in
                                EntryCard(entry: entry) { delete(entry) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Nuova parola").font(Typo.display(20))
                Spacer()
                Eyebrow(controller.engineKind == .apple ? "Suggerita al riconoscimento" : "Corretta dopo la trascrizione")
            }
            HStack(spacing: 10) {
                FieldBox(symbol: "textformat", placeholder: "Come va scritta · es. Claude Code", text: $term)
                    .focused($termFocused)
                    .frame(maxWidth: 300)
                Image(systemName: "arrow.left").foregroundStyle(Theme.textTertiary)
                FieldBox(symbol: "ear", placeholder: "Come viene sentita · es. cloud code, clod code", text: $variants)
                Button(action: add) {
                    Label("Aggiungi", systemImage: "plus")
                        .font(.system(size: 12.5, weight: .semibold))
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Theme.coral, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(term.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
        .padding(20)
        .background(Theme.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
    }

    private func add() {
        let t = term.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if let existing = entries.first(where: { $0.term.caseInsensitiveCompare(t) == .orderedSame }) {
            existing.variants = [existing.variants, variants].filter { !$0.isEmpty }.joined(separator: ", ")
        } else {
            context.insert(DictionaryEntry(term: t, variants: variants))
        }
        try? context.save()
        term = ""; variants = ""; termFocused = true
    }

    private func delete(_ entry: DictionaryEntry) {
        withAnimation { context.delete(entry) }
        try? context.save()
    }
}

private struct FieldBox: View {
    let symbol: String
    let placeholder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            TextField(placeholder, text: $text).textFieldStyle(.plain).font(.system(size: 13))
        }
        .padding(.horizontal, 11).frame(height: 34)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.stroke))
    }
}

private struct EntryCard: View {
    let entry: DictionaryEntry
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(entry.term).font(.system(size: 17, weight: .medium, design: .serif))
                Spacer()
                IconAction(symbol: "trash", help: "Elimina", action: onDelete).opacity(hover ? 1 : 0)
            }
            if entry.variantList.isEmpty {
                Text("Solo suggerimento, nessuna variante").font(.system(size: 11.5)).foregroundStyle(Theme.textTertiary)
            } else {
                FlowTags(tags: entry.variantList)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(Theme.raised.opacity(hover ? 0.9 : 0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(hover ? Theme.coral.opacity(0.3) : Theme.stroke))
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .contextMenu { Button("Elimina", systemImage: "trash", role: .destructive, action: onDelete) }
    }
}

private struct FlowTags: View {
    let tags: [String]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags.prefix(4), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11))
                    .strikethrough(color: Theme.coral.opacity(0.6))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.05), in: Capsule())
                    .lineLimit(1)
            }
            if tags.count > 4 {
                Text("+\(tags.count - 4)").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
