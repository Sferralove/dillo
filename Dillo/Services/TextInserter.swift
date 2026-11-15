import AppKit
import ApplicationServices
import os

let diagLog = Logger(subsystem: "com.angelosferra.dillo", category: "insert")

enum InsertResult { case pasted, copiedOnly }

/// Inserisce testo nell'app in primo piano: clipboard + ⌘V sintetico, poi ripristina la clipboard.
/// Senza permesso Accessibilità macOS scarta in silenzio gli eventi sintetici:
/// in quel caso il testo resta negli appunti e lo segnaliamo.
final class TextInserter {
    func insert(_ text: String) async -> InsertResult {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        let trusted = AXIsProcessTrusted()
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        diagLog.notice("insert: trusted=\(trusted, privacy: .public) front=\(front, privacy: .public) path=\(Bundle.main.bundlePath, privacy: .public) len=\(text.count, privacy: .public)")
        guard trusted else { return .copiedOnly }

        // Lascia al sistema il tempo di registrare il rilascio di ⌥ prima del ⌘V.
        try? await Task.sleep(for: .milliseconds(60))

        let src = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 9
        for keyDown in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: keyDown)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }

        // Ripristina gli appunti dopo che l'app di destinazione ha letto il contenuto.
        try? await Task.sleep(for: .milliseconds(400))
        if let previous {
            pb.clearContents()
            pb.setString(previous, forType: .string)
        }
        diagLog.notice("insert: posted cmd+V")
        return .pasted
    }
}
