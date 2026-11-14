import AppKit

/// Ascolta globalmente un tasto modificatore (es. ⌥ destro) per la dettatura.
/// Richiede il permesso Accessibilità.
@MainActor
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// Esc durante una dettatura.
    var onCancel: (() -> Void)?
    var isRecording = false
    var key: HotkeyKey = .rightOption { didSet { isDown = false } }

    private var isDown = false
    private var monitors: [Any] = []

    func start() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { handler($0); return $0 }) { monitors.append(l) }
        // Esc annulla la dettatura in corso, ovunque.
        let esc: (NSEvent) -> Bool = { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.isRecording, event.keyCode == 53 else { return false }
                self.onCancel?()
                return true
            }
        }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { _ = esc($0) }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { esc($0) ? nil : $0 }) { monitors.append(l) }
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == key.keyCode else { return }
        let pressed = event.modifierFlags.contains(key.flag)
        if pressed, !isDown { isDown = true; onPress?() }
        else if !pressed, isDown { isDown = false; onRelease?() }
    }
}
