import SwiftData
import SwiftUI

struct DictionaryPage: View {
    @Environment(\.modelContext) private var context
    @Environment(DictationController.self) private var controller
    @Query(sort: \DictionaryEntry.term) private var entries: [DictionaryEntry]
    @Query private var transcripts: [Transcript]
    @State private var search = ""
    @State private var term = ""
    @State private var variants = ""
    @State private var feedback: String?
    @State private var error: String?
    @State private var editing: DictionaryEntry?

    private var filtered: [DictionaryEntry] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? entries : entries.filter {
            $0.term.localizedStandardContains(q) || $0.variants.localizedStandardContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Dizionario",
                       subtitle: "\(entries.count) voci · \(transcripts.reduce(0) { $0 + $1.corrections }) correzioni applicate",
                       search: $search, searchPrompt: "Cerca nel dizionario")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nuova parola").font(Typo.display(20))
                        DictionaryFields(term: $term, variants: $variants)
                        HStack(alignment: .center) {
                            Text(controller.engineKind == .apple
                                 ? "La parola aiuta il riconoscimento; le varianti vengono corrette nel testo."
                                 : "Le varianti vengono sostituite con la scrittura corretta dopo la trascrizione.")
                                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            Spacer(minLength: 12)
                            Button("Aggiungi", systemImage: "plus", action: add)
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.defaultAction)
                                .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.coral).font(.callout) }
                        else if let feedback { Label(feedback, systemImage: "checkmark.circle").foregroundStyle(Theme.textSecondary).font(.callout) }
                    }
                    .padding(20).card(radius: 16)
                    if entries.isEmpty {
                        EmptyState(symbol: "character.book.closed", title: "Insegna a Dillo le tue parole",
                                   text: "Aggiungi nomi, sigle e termini tecnici. Le varianti sono facoltative.")
                            .frame(minHeight: 240)
                    } else if filtered.isEmpty {
                        EmptyState(symbol: "magnifyingglass", title: "Nessun risultato", text: "Nessuna voce contiene “\(search)”.")
                            .frame(minHeight: 200)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14, alignment: .top)], spacing: 14) {
                            ForEach(filtered) { entry in
                                EntryCard(entry: entry, onEdit: { editing = entry }, onDelete: { delete(entry) })
                            }
                        }
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 30)
            }
        }
        .sheet(item: $editing) { entry in
            DictionaryEditor(entry: entry, entries: entries)
        }
    }

    private func add() {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let existing = entries.first { $0.term.caseInsensitiveCompare(t) == .orderedSame }
        let entry = existing ?? DictionaryEntry(term: t)
        let oldVariants = entry.variants
        entry.variants = DictionaryEntry.normalizedVariants([oldVariants, variants].joined(separator: ","))
        if existing == nil { context.insert(entry) }
        do {
            try context.save()
            feedback = existing == nil ? "“\(t)” aggiunta al dizionario." : "Varianti di “\(t)” aggiornate."
            error = nil; term = ""; variants = ""
        } catch {
            if existing == nil { context.delete(entry) } else { entry.variants = oldVariants }
            self.error = "Impossibile salvare la voce. Riprova."
        }
    }

    private func delete(_ entry: DictionaryEntry) {
        context.delete(entry)
        do { try context.save() }
        catch { context.rollback(); self.error = "Impossibile eliminare la voce. Riprova." }
    }
}

private struct DictionaryFields: View {
    @Binding var term: String
    @Binding var variants: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                termField.frame(minWidth: 230)
                variantsField.frame(minWidth: 270)
            }
            VStack(alignment: .leading, spacing: 16) { termField; variantsField }
        }
    }
    private var termField: some View {
        field(title: "Scrittura corretta", example: "Esempio: Claude Code", prompt: "Parola o espressione", text: $term)
    }
    private var variantsField: some View {
        field(title: "Varianti riconosciute · facoltative", example: "Esempio: cloud code, clod code · separate da virgola", prompt: "Come viene trascritta per errore", text: $variants)
    }
    private func field(title: String, example: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder).controlSize(.large)
                .accessibilityLabel(title)
            Text(example).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DictionaryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: DictionaryEntry
    let entries: [DictionaryEntry]
    @State private var term: String
    @State private var variants: String
    @State private var error: String?

    init(entry: DictionaryEntry, entries: [DictionaryEntry]) {
        self.entry = entry; self.entries = entries
        _term = State(initialValue: entry.term)
        _variants = State(initialValue: entry.variants)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Modifica parola").font(Typo.pageTitle)
            DictionaryFields(term: $term, variants: $variants)
            if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Theme.coral).font(.callout) }
            HStack {
                Spacer()
                Button("Annulla") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Salva modifiche", action: save)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28).frame(width: 560)
        .background(Theme.surface)
    }
    private func save() {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        guard !entries.contains(where: { $0.id != entry.id && $0.term.caseInsensitiveCompare(t) == .orderedSame }) else {
            error = "Questa parola esiste già. Modifica la voce esistente oppure scegli un altro nome."
            return
        }
        let oldTerm = entry.term, oldVariants = entry.variants
        entry.term = t; entry.variants = DictionaryEntry.normalizedVariants(variants)
        do { try context.save(); dismiss() }
        catch { entry.term = oldTerm; entry.variants = oldVariants; self.error = "Impossibile salvare le modifiche. Riprova." }
    }
}

private struct EntryCard: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(entry.term).font(.system(size: 18, weight: .medium, design: .serif))
                Spacer(minLength: 8)
                Button(action: onEdit) { Image(systemName: "pencil") }
                    .buttonStyle(.plain).foregroundStyle(Theme.textSecondary)
                    .help("Modifica parola").accessibilityLabel("Modifica \(entry.term)")
                Menu {
                    Button("Modifica", systemImage: "pencil", action: onEdit)
                    Button("Elimina", systemImage: "trash", role: .destructive, action: onDelete)
                } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("Azioni per \(entry.term)")
            }
            if entry.variantList.isEmpty {
                Text("Suggerimento al riconoscimento").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            } else {
                Text("Corregge queste varianti:").font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array((expanded ? entry.variantList : Array(entry.variantList.prefix(3))).enumerated()), id: \.offset) { _, tag in
                        Text(tag).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                if entry.variantList.count > 3 {
                    Button(expanded ? "Mostra meno" : "Mostra tutte (\(entry.variantList.count))") { expanded.toggle() }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.coral)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
        .card()
        .contextMenu {
            Button("Modifica", systemImage: "pencil", action: onEdit)
            Button("Elimina", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
