import SwiftData
import SwiftUI

struct HistoryPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transcript.createdAt, order: .reverse) private var transcripts: [Transcript]
    @State private var search = ""

    private var filtered: [Transcript] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return transcripts }
        return transcripts.filter { $0.text.localizedStandardContains(q) || ($0.appName ?? "").localizedStandardContains(q) }
    }

    private var groups: [(day: Date, items: [Transcript])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.createdAt) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Cronologia", subtitle: subtitle, search: $search, searchPrompt: "Cerca nelle trascrizioni") {
                if !transcripts.isEmpty {
                    HStack {
                        Spacer()
                        Menu {
                            ForEach(HistoryExporter.Format.allCases) { f in
                                Button("Esporta in \(f.title)…") { HistoryExporter.export(filtered, as: f) }
                            }
                        } label: {
                            Label(search.isEmpty ? "Esporta" : "Esporta risultati", systemImage: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
            }
            if transcripts.isEmpty {
                EmptyState(symbol: "waveform", title: "Ancora nessuna dettatura",
                           text: "Tieni premuta la scorciatoia in qualsiasi app, oppure usa il pulsante del microfono qui sopra.")
            } else if filtered.isEmpty {
                EmptyState(symbol: "magnifyingglass", title: "Nessun risultato", text: "Nessuna trascrizione contiene “\(search)”.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups, id: \.day) { group in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                                        TranscriptRow(item: item, highlight: search) { delete(item) }
                                        if i < group.items.count - 1 {
                                            Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 112)
                                        }
                                    }
                                }
                                .background(Theme.raised.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
                                .padding(.bottom, 22)
                            } header: {
                                HStack {
                                    Eyebrow(dayTitle(group.day))
                                }
                                .padding(.vertical, 10)
                                .background(Theme.surface)
                            }
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var subtitle: String {
        "\(transcripts.count) trascrizioni"
    }

    private func delete(_ item: Transcript) {
        withAnimation { context.delete(item) }
        try? context.save()
    }

    private func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Oggi" }
        if cal.isDateInYesterday(day) { return "Ieri" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

struct TranscriptRow: View {
    let item: Transcript
    var highlight: String
    var onDelete: () -> Void
    @State private var copied = false
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 5) {
                    AppIcon(bundleID: item.appBundleID, size: 14)
                    Text(item.appName ?? "—").lineLimit(1)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
            }
            .frame(width: 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(attributed)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    meta("\(item.wordCount) parole")
                    meta(String(format: "%.1f s", item.duration))
                    if item.corrections > 0 { meta(item.corrections == 1 ? "1 correzione" : "\(item.corrections) correzioni", color: Theme.coral.opacity(0.8)) }
                    meta(item.engine)
                }
            }

            HStack(spacing: 4) {
                IconAction(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copia", active: copied, action: copy)
                IconAction(symbol: "trash", help: "Elimina", action: onDelete)
                    .opacity(hovering ? 1 : 0)
            }
            .opacity(hovering || copied ? 1 : 0.35)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white.opacity(hovering ? 0.025 : 0))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contextMenu {
            Button("Copia", systemImage: "doc.on.doc", action: copy)
            Divider()
            Button("Elimina", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var attributed: AttributedString {
        var s = AttributedString(item.text)
        let q = highlight.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return s }
        var start = s.startIndex
        while let r = s[start...].range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            s[r].backgroundColor = Theme.coral.opacity(0.35)
            start = r.upperBound
        }
        return s
    }

    private func meta(_ text: String, color: Color = Theme.textTertiary) -> some View {
        Text(text).font(.system(size: 11).monospacedDigit()).foregroundStyle(color)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        withAnimation { copied = true }
        Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { copied = false } }
    }
}

struct IconAction: View {
    let symbol: String
    let help: String
    var active = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(active ? Theme.coral : .white.opacity(hover ? 0.95 : 0.7))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(hover ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

struct EmptyState: View {
    let symbol: String, title: String, text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(Theme.coral)
                .frame(width: 64, height: 64)
                .background(Theme.coral.opacity(0.1), in: Circle())
            Text(title).font(Typo.display(22))
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}
