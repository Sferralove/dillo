import AppKit

/// Ascolta globalmente un tasto modificatore (es. ⌥ destro) per la dettatura.
/// Richiede il permesso Accessibilità.
///
/// Il tasto scelto serve anche a scrivere: sulla tastiera italiana ⌥ dà `@`, `#`, `[ ]`, `{ }`.
/// Se mentre è premuto arriva un altro tasto, la pressione è una combinazione e non una dettatura:
/// lo segnaliamo con `onChord` e il rilascio lo riporta, così il controller la annulla senza rumore.
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    /// Rilascio del tasto: quanto è stato tenuto premuto e se nel frattempo è stato usato con un altro tasto.
    var onRelease: ((_ heldFor: Duration, _ chorded: Bool) -> Void)?
    /// Un altro tasto premuto mentre il tasto di dettatura è giù (una volta per pressione).
    var onChord: (() -> Void)?
    /// Esc durante una dettatura.
    var onCancel: (() -> Void)?
    var isRecording = false
    var key: HotkeyKey = .rightOption { didSet { isDown = false } }

    private var isDown = false
    private var chorded = false
    private var pressedAt = ContinuousClock.now
    private var monitors: [Any] = []

    func start() {
        // I monitor di NSEvent chiamano i blocchi sul main thread, come il resto di questa classe.
        let flags: (NSEvent) -> Void = { [weak self] event in self?.handleFlags(event) }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { flags($0); return $0 }) { monitors.append(l) }

        let keyDown: (NSEvent) -> Bool = { [weak self] event in self?.handleKeyDown(event) ?? false }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { _ = keyDown($0) }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { keyDown($0) ? nil : $0 }) { monitors.append(l) }
    }

    private func handleFlags(_ event: NSEvent) {
        guard event.keyCode == key.keyCode else { return }
        let pressed = event.modifierFlags.contains(key.flag)
        if pressed, !isDown {
            isDown = true
            chorded = false
            pressedAt = .now
            onPress?()
        } else if !pressed, isDown {
            isDown = false
            onRelease?(.now - pressedAt, chorded)
        }
    }

    /// Restituisce true se l'evento va consumato (solo Esc durante una dettatura, nelle finestre di Dillo).
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Esc annulla la dettatura in corso, ovunque.
        if event.keyCode == 53, isRecording {
            onCancel?()
            return true
        }
        if isDown, !chorded {
            chorded = true
            onChord?()
        }
        return false
    }
}
