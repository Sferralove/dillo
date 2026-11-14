import SwiftData
import SwiftUI

@main
struct DilloApp: App {
    private let container: ModelContainer
    @State private var controller: DictationController

    /// True quando l'app fa da host per i test unitari: niente scorciatoie, microfono o modelli.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        let container = Self.makeContainer()
        self.container = container
        #if DEBUG
        if DebugSnapshot.isDemo { DebugSnapshot.seed(container.mainContext) }
        #endif
        let controller = DictationController(container: container, startServices: !Self.isRunningTests)
        _controller = State(initialValue: controller)
        #if DEBUG
        DebugSnapshot.renderAll(controller: controller, container: container)
        #endif
    }

    /// Apre il database. Se il file è danneggiato o non migrabile, lo mette da parte (non lo cancella)
    /// e ne crea uno nuovo, così l'app si avvia sempre.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Transcript.self, DictionaryEntry.self])
        if isRunningTests { return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) }
        #if DEBUG
        if DebugSnapshot.isDemo { return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) }
        #endif
        let dir = URL.applicationSupportDirectory.appending(path: "Dillo", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "Dillo.store")
        if let c = try? ModelContainer(for: schema, configurations: ModelConfiguration(url: url)) { return c }

        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        for suffix in ["", "-shm", "-wal"] {
            let file = dir.appending(path: "Dillo.store" + suffix)
            try? FileManager.default.moveItem(at: file, to: dir.appending(path: "Dillo-danneggiato-\(stamp).store" + suffix))
        }
        if let c = try? ModelContainer(for: schema, configurations: ModelConfiguration(url: url)) { return c }
        return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    var body: some Scene {
        Window("Dillo", id: "main") {
            MainView()
                .environment(controller)
                .frame(minWidth: 980, minHeight: 640)
                .preferredColorScheme(.dark)
                .tint(Theme.coral)
                .modifier(FirstLaunch())
        }
        .modelContainer(container)
        .defaultSize(width: 1180, height: 780)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Informazioni su Dillo") { AboutPanel.show() }
            }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Registrazione") {
                Button(controller.isRecording ? "Interrompi registrazione" : "Avvia registrazione") {
                    controller.toggleFromApp()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!(controller.isReady || controller.isRecording))
                Button("Annulla dettatura") { controller.cancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!controller.isRecording)
            }
            CommandGroup(replacing: .help) {
                OpenOnboardingButton()
            }
        }

        Window("Benvenuto in Dillo", id: "onboarding") {
            OnboardingView()
                .environment(controller)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environment(controller)
                .modelContainer(container)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(controller)
        } label: {
            Image(nsImage: controller.menuBarIcon.image)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Al primo avvio apre la guida introduttiva.
private struct FirstLaunch: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    func body(content: Content) -> some View {
        content.task {
            guard !DilloApp.isRunningTests, !UserDefaults.standard.bool(forKey: Pref.onboarded) else { return }
            #if DEBUG
            if DebugSnapshot.isDemo { return }
            #endif
            openWindow(id: "onboarding")
        }
    }
}

private struct OpenOnboardingButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Guida introduttiva a Dillo") { openWindow(id: "onboarding") }
    }
}
