import AVFoundation
import SwiftUI

/// Benvenuto al primo avvio: presenta Dillo, chiede i permessi e fa provare la prima dettatura.
struct OnboardingView: View {
    @Environment(DictationController.self) private var controller
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var step: Step = .welcome
    @State private var micGranted = Permissions.microphoneGranted
    @State private var tested = false

    enum Step: Int, CaseIterable {
        case welcome, microphone, accessibility, tryIt
        var label: String {
            switch self {
            case .welcome: "Benvenuto"
            case .microphone: "Microfono"
            case .accessibility: "Accessibilità"
            case .tryIt: "Prova"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(title).font(.system(size: 32, weight: .bold, design: .serif))
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 480)
            .padding(.top, 44)
            .id("title-\(step.rawValue)")
            .transition(.opacity)

            hero
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(Theme.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke))
                .padding(.horizontal, 56)
                .padding(.top, 28)

            StepIndicator(current: step).padding(.top, 26)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(notes, id: \.1) { note in
                    Label {
                        Text(note.1).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.75))
                    } icon: {
                        Image(systemName: note.0).foregroundStyle(Theme.coral)
                    }
                }
            }
            .padding(.top, 20)
            .frame(height: 64, alignment: .top)

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        Text(primaryTitle)
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.primaryLarge)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: 420)

                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 30)
        }
        .frame(width: 640, height: 640)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .tint(Theme.coral)
        .animation(.snappy(duration: 0.3), value: step)
        .task {
            // Aggiorna lo stato dei permessi mentre l'utente li concede in Impostazioni di Sistema.
            while !Task.isCancelled {
                micGranted = Permissions.microphoneGranted
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: controller.lastTranscriptID) { if step == .tryIt { tested = true } }
    }

    // MARK: Contenuti dei passi

    private var title: String {
        switch step {
        case .welcome: "La tua voce, ovunque scrivi"
        case .microphone: "Il microfono"
        case .accessibility: "Scorciatoia e incolla"
        case .tryIt: tested ? "Perfetto!" : "Prova subito"
        }
    }

    private var subtitle: String {
        let key = controller.hotkeyKey.glyph
        switch step {
        case .welcome: return "Tieni premuto \(key), parla, rilascia: il testo appare dove si trova il cursore."
        case .microphone: return "Dillo ascolta solo mentre tieni premuto il tasto, e quando registra lo vedi sempre."
        case .accessibility: return "Serve a macOS per farti usare la scorciatoia in ogni app e incollare il testo."
        case .tryIt: return tested ? "Dillo è pronto. Usalo in qualsiasi app." : "\(controller.hotkeyMode == .hold ? "Tieni premuto" : "Premi") \(key) e di' una frase."
        }
    }

    @ViewBuilder private var hero: some View {
        switch step {
        case .welcome:
            VStack(spacing: 18) {
                RobinView(waves: [1, 0.75, 0.5], waveBoost: 1.1).frame(height: 96)
                HStack(spacing: 10) {
                    KeyCap(label: controller.hotkeyKey.glyph, size: 34, accent: true)
                    Text("tieni premuto e parla").font(.system(size: 15, weight: .medium))
                }
            }
        case .microphone:
            PermissionHero(symbol: "mic.fill", granted: micGranted,
                           grantedText: "Microfono pronto", pendingText: "Accesso al microfono")
        case .accessibility:
            PermissionHero(symbol: "accessibility", granted: controller.axGranted,
                           grantedText: "Accessibilità concessa", pendingText: "Attiva Dillo nell'elenco")
        case .tryIt:
            tryItHero
        }
    }

    private var tryItHero: some View {
        @Bindable var controller = controller
        return VStack(spacing: 16) {
            Group {
                if controller.isRecording || controller.state == .transcribing {
                    VStack(spacing: 12) {
                        HUDRobin(level: controller.level, busy: controller.state == .transcribing)
                            .scaleEffect(1.6).frame(height: 50)
                        Group {
                            if controller.partialText.isEmpty { Text("Ti ascolto…").italic().foregroundStyle(Theme.textSecondary) }
                            else { RevealText(text: controller.partialText) }
                        }
                    }
                } else if tested, let last = controller.lastTranscriptText {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(.green)
                        Text("“\(last)”")
                    }
                } else {
                    VStack(spacing: 14) {
                        KeyCap(label: controller.hotkeyKey.glyph, size: 44, accent: true)
                        Text(controller.isReady ? "In attesa della tua voce…" : controller.state.title)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .font(.system(size: 15, design: .serif))
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)

            Picker("Tasto", selection: $controller.hotkeyKey) {
                ForEach(HotkeyKey.allCases) { Text("\($0.title) · \($0.glyph)").tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var notes: [(String, String)] {
        switch step {
        case .welcome: [("lock.shield", "100% sul tuo Mac: l'audio non lascia mai questo computer."),
                        ("bolt", "Funziona in qualsiasi app, anche offline.")]
        case .microphone: [("eye", "Quando Dillo ascolta lo vedi nella barra dei menu e sullo schermo."),
                           ("lock.shield", "L'audio non viene mai salvato né inviato.")]
        case .accessibility: [("hand.raised", "Richiesto per riconoscere il tasto e incollare il testo."),
                              ("arrow.uturn.left", "Dopo averlo attivato, torna qui: il passo si aggiorna da solo.")]
        case .tryIt: [("escape", "Premi esc per annullare una dettatura."),
                      ("gearshape", "Tasto, microfono e lingua si cambiano nelle Impostazioni (⌘,).")]
        }
    }

    // MARK: Azioni

    private var primaryTitle: String {
        switch step {
        case .welcome: "Iniziamo"
        case .microphone: micGranted ? "Continua" : "Consenti il microfono"
        case .accessibility: controller.axGranted ? "Continua" : "Apri Accessibilità"
        case .tryIt: "Inizia a usare Dillo"
        }
    }

    private var secondaryTitle: String { step == .welcome ? "Configura più tardi" : "Indietro" }

    private func primaryAction() {
        switch step {
        case .welcome: next()
        case .microphone:
            if micGranted { next(); return }
            if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            } else {
                Task { micGranted = await Permissions.requestMicrophone() }
            }
        case .accessibility:
            if controller.axGranted { next(); return }
            Permissions.promptAccessibility()
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        case .tryIt: finish()
        }
    }

    private func secondaryAction() {
        if step == .welcome { finish() } else { step = Step(rawValue: step.rawValue - 1) ?? .welcome }
    }

    private func next() { step = Step(rawValue: step.rawValue + 1) ?? .tryIt }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Pref.onboarded)
        dismissWindow(id: "onboarding")
    }
}

/// Indicatore dei passi con etichette: completati e attuale in corallo.
private struct StepIndicator: View {
    let current: OnboardingView.Step

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OnboardingView.Step.allCases, id: \.self) { s in
                VStack(spacing: 8) {
                    Circle()
                        .fill(s.rawValue <= current.rawValue ? Theme.coral : Color.white.opacity(0.18))
                        .frame(width: s == current ? 10 : 8, height: s == current ? 10 : 8)
                    Text(s.label)
                        .font(.system(size: 12, weight: s == current ? .semibold : .regular))
                        .foregroundStyle(s == current ? .white : Theme.textSecondary)
                }
                .frame(width: 104)
            }
        }
    }
}

/// Illustrazione di un permesso: icona grande che diventa una spunta quando è concesso.
private struct PermissionHero: View {
    let symbol: String
    let granted: Bool
    let grantedText: String
    let pendingText: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.coral.opacity(granted ? 0 : 0.12)).frame(width: 96, height: 96)
                Circle().strokeBorder(Theme.coral.opacity(granted ? 0 : 0.3)).frame(width: 96, height: 96)
                Image(systemName: granted ? "checkmark.circle.fill" : symbol)
                    .font(.system(size: granted ? 54 : 38, weight: .medium))
                    .foregroundStyle(granted ? .green : Theme.coral)
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(granted ? grantedText : pendingText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(granted ? .white : .white.opacity(0.8))
        }
        .animation(.snappy, value: granted)
    }
}
