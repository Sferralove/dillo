import AppKit
import UniformTypeIdentifiers

/// Esporta la cronologia in Markdown (leggibile) o CSV (fogli di calcolo).
enum HistoryExporter {
    enum Format: String, CaseIterable, Identifiable {
        case markdown, csv
        var id: String { rawValue }
        var title: String { self == .markdown ? "Markdown" : "CSV" }
        var type: UTType { self == .markdown ? UTType(filenameExtension: "md") ?? .plainText : .commaSeparatedText }
    }

    static func render(_ items: [Transcript], as format: Format) -> String {
        let sorted = items.sorted { $0.createdAt < $1.createdAt }
        switch format {
        case .markdown:
            var out = "# Dillo — Cronologia\n\nEsportata il \(Date.now.formatted(date: .long, time: .shortened)) · \(items.count) trascrizioni\n"
            var currentDay = ""
            for t in sorted {
                let day = t.createdAt.formatted(date: .complete, time: .omitted)
                if day != currentDay { out += "\n## \(day.capitalized)\n"; currentDay = day }
                out += "\n**\(t.createdAt.formatted(date: .omitted, time: .shortened))** · \(t.appName ?? "—") · \(t.wordCount) parole\n\n\(t.text)\n"
            }
            return out
        case .csv:
            func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            var out = "data,app,parole,durata_s,latenza_s,motore,correzioni,testo\n"
            let iso = ISO8601DateFormatter()
            for t in sorted {
                out += [iso.string(from: t.createdAt), esc(t.appName ?? ""), "\(t.wordCount)",
                        String(format: "%.2f", t.duration), String(format: "%.3f", t.latency),
                        esc(t.engine), "\(t.corrections)", esc(t.text)].joined(separator: ",") + "\n"
            }
            return out
        }
    }

    static func export(_ items: [Transcript], as format: Format) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.type]
        panel.nameFieldStringValue = "Dillo cronologia \(Date.now.formatted(.iso8601.year().month().day())).\(format == .markdown ? "md" : "csv")"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? render(items, as: format).write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
