#if DEBUG
import AppKit
import SwiftData
import SwiftUI

/// Solo in Debug: `-demo` usa un database temporaneo con dati di esempio,
/// `-snapshot <cartella>` salva un PNG di ogni pagina della finestra principale.
enum DebugSnapshot {
    static var isDemo: Bool { CommandLine.arguments.contains("-demo") }

    static var snapshotDir: URL? {
        guard let i = CommandLine.arguments.firstIndex(of: "-snapshot"), i + 1 < CommandLine.arguments.count else { return nil }
        return URL(fileURLWithPath: CommandLine.arguments[i + 1])
    }

    @MainActor static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        let samples = [
            ("Ciao Marco, ti confermo la riunione di domani alle dieci. Porto io le slide aggiornate con i numeri del trimestre.", "Mail", "com.apple.mail"),
            ("Refactoring del modulo di autenticazione: separiamo il token refresh dal client HTTP e aggiungiamo i test.", "Claude", "com.anthropic.claudefordesktop"),
            ("Ricordati di comprare il latte, il pane e di passare in farmacia prima delle sette.", "Note", "com.apple.Notes"),
            ("Ok, perfetto, ci sentiamo dopo pranzo per chiudere la proposta.", "Messaggi", "com.apple.MobileSMS"),
            ("Scrivi una funzione in Swift che calcoli la serie di giorni consecutivi a partire da un elenco di date.", "Claude", "com.anthropic.claudefordesktop"),
            ("Il design della dashboard deve restare scuro con l'accento corallo, tipografia serif per i titoli.", "Safari", "com.apple.Safari"),
        ]
        for day in 0..<120 where (day % 9 != 4 && day % 13 != 7) || day < 20 {
            let count = (day * 7 + 3) % 5 + (day < 20 ? 2 : 0)
            for k in 0..<count {
                let s = samples[(day + k) % samples.count]
                let date = cal.date(byAdding: .minute, value: -(day * 1440 + k * 97 + 30), to: .now)!
                let words = s.0.split(separator: " ").count
                context.insert(Transcript(text: s.0, createdAt: date, duration: Double(words) / 2.6,
                                          latency: 0.12 + Double(k) * 0.03, engine: k % 4 == 0 ? "Parakeet v3" : "Apple Speech",
                                          appName: s.1, appBundleID: s.2, corrections: (day + k) % 6 == 0 ? 1 : 0))
            }
        }
        context.insert(DictionaryEntry(term: "Claude Code", variants: "cloud code, clod code"))
        context.insert(DictionaryEntry(term: "SwiftUI", variants: "swift ui, suif ui"))
        context.insert(DictionaryEntry(term: "Dillo", variants: "dilo"))
        context.insert(DictionaryEntry(term: "Hugging Face", variants: "aging face"))
        context.insert(DictionaryEntry(term: "TestFlight"))
        try? context.save()
    }

    /// Renderizza ogni pagina in una finestra fuori schermo (non dipende dalle scene SwiftUI).
    @MainActor static func renderAll(controller: DictationController, container: ModelContainer) {
        guard let dir = snapshotDir else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for page in Page.allCases {
                let root = MainView(initialPage: page)
                    .environment(controller)
                    .modelContainer(container)
                    .preferredColorScheme(.dark)
                    .tint(Theme.coral)
                    .frame(width: 1180, height: 780)
                let window = NSWindow(contentRect: NSRect(x: -4000, y: 0, width: 1180, height: 780),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: .darkAqua)
                window.contentView = NSHostingView(rootView: root)
                window.orderFrontRegardless()
                try? await Task.sleep(for: .seconds(1.5))
                if let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: dir.appending(path: "\(page.rawValue).png"))
                }
                window.orderOut(nil)
            }
            // Benvenuto
            do {
                let window = NSWindow(contentRect: NSRect(x: -4000, y: 0, width: 620, height: 520), styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: .darkAqua)
                window.contentView = NSHostingView(rootView: OnboardingView().environment(controller))
                window.orderFrontRegardless()
                try? await Task.sleep(for: .seconds(1.5))
                if let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: dir.appending(path: "onboarding.png"))
                }
                window.orderOut(nil)
            }
            // Icone della barra dei menu, ingrandite 4x su sfondo scuro
            let icons: [(String, NSImage)] = [
                ("menubar-idle", MenuBarIconModel.render(mode: .idle, waves: [])),
                ("menubar-rec", MenuBarIconModel.render(mode: .recording, waves: [1, 0.7, 0.3])),
                ("robin-large", NSImage(size: NSSize(width: 320, height: 256), flipped: true) { r in
                    RobinMark.draw(in: NSGraphicsContext.current!.cgContext, rect: r, waves: [1, 1, 1]); return true }),
            ]
            for (name, icon) in icons {
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 184, pixelsHigh: 144, bitsPerSample: 8, samplesPerPixel: 4,
                                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                NSColor(white: 0.15, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 184, height: 144).fill()
                if icon.isTemplate {
                    let tinted = icon.copy() as! NSImage
                    tinted.lockFocus(); NSColor.white.set(); NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop); tinted.unlockFocus()
                    tinted.draw(in: NSRect(x: 0, y: 0, width: 184, height: 144))
                } else {
                    icon.draw(in: NSRect(x: 0, y: 0, width: 184, height: 144))
                }
                NSGraphicsContext.restoreGraphicsState()
                try? rep.representation(using: .png, properties: [:])?.write(to: dir.appending(path: "\(name).png"))
            }
            NSApp.terminate(nil)
        }
    }
}
#endif
