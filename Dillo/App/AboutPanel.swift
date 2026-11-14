import AppKit

/// Pannello "Informazioni su Dillo" con versione e crediti di terze parti (richiesti dalle licenze).
enum AboutPanel {
    @MainActor static func show() {
        let credits = NSMutableAttributedString()
        let body: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        let bold: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.labelColor]
        func add(_ title: String, _ text: String, link: String? = nil) {
            credits.append(NSAttributedString(string: title + "\n", attributes: bold))
            var attrs = body
            if let link, let url = URL(string: link) { attrs[.link] = url }
            credits.append(NSAttributedString(string: text + "\n\n", attributes: attrs))
        }
        add("Dettatura privata, tutta sul tuo Mac.", "L'audio non lascia mai questo computer.")
        add("Apple Speech", "Riconoscimento vocale di macOS (SpeechAnalyzer).")
        add("Parakeet TDT 0.6B v3", "© NVIDIA — licenza CC-BY-4.0.", link: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3")
        add("FluidAudio", "© FluidInference — licenza Apache 2.0.", link: "https://github.com/FluidInference/FluidAudio")

        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "Dillo",
        ])
    }
}
