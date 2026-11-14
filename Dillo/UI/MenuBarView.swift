import SwiftUI

/// Elemento secondario nella barra dei menu: stato e scorciatoie rapide.
struct MenuBarView: View {
    @Environment(DictationController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Dillo — \(controller.state.title)")
        Text("\(controller.engineName) · \(controller.hotkeyKey.glyph)")
        if let lang = controller.languageSuggestion {
            Divider()
            Button("Stai parlando \(lang.localizedName)? Passa a \(lang.name)") { controller.acceptLanguageSuggestion() }
        }
        Divider()
        Button(controller.isRecording ? "Interrompi registrazione" : "Avvia registrazione") {
            controller.toggleFromApp()
        }
        .disabled(!(controller.isReady || controller.isRecording))
        Divider()
        Button("Apri Dillo") {
            openWindow(id: "main")
            NSApp.activate()
        }
        SettingsLink { Text("Impostazioni…") }
            .keyboardShortcut(",")
        Button("Informazioni su Dillo") { AboutPanel.show() }
        Divider()
        Button("Esci da Dillo") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
