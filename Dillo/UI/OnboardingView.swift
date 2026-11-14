import AVFoundation
import SwiftUI

/// Benvenuto al primo avvio: presenta Dillo, chiede i permessi e fa provare la prima dettatura.
struct OnboardingView: View {
    @Environment(DictationController.self) private var controller
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var step = 0
    @State private var micGranted = Permissions.microphoneGranted
    @State private var tested = false

    private let steps = 4

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0: welcome
                case 1: microphone
                case 2: accessibility
                default: tryIt
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)

            footer
        }
        .frame(width: 620, height: 520)
        .background(Theme.graphite)
        .preferredColorScheme(.dark)
        .tint(Theme.coral)
        .task {
            // Aggiorna lo stato dei permessi mentre l'utente li concede in Impostazioni di Sistema.
            while !Task.isCancelled {
                micGranted = Permissions.microphoneGranted
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: controller.lastTranscriptID) { if step == 3 { tested = true } }
    }

    // MARK: Passi

    private var welcome: some View {
        StepLayout(title: "Benvenuto in Dillo",
                   text: "Parla, e il testo appare dove stai scrivendo. In qualsiasi app, con una sola scorciatoia. Tutto resta sul tuo Mac: l'audio non viene mai inviato a nessun server.") {
            RobinView(waves: [1, 0.75, 0.5], waveBoost: 1.1).frame(height: 120)
        }
    }

    private var microphone: some View {
        StepLayout(title: "Il microfono",
                   text: "Dillo ascolta solo mentre tieni premuta la scorciatoia, e quando registra lo vedi sempre: nella barra dei menu e nell'indicatore in basso.") {
            PermissionCard(symbol: "mic.fill", title: "Accesso al microfono", granted: micGranted) {
                if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                } else {
                    Task { micGranted = await Permissions.requestMicrophone() }
                }
            }
        }
    }

    private var accessibility: some View {
        StepLayout(title: "Scorciatoia e incolla",
                   text: "Per ascoltare la scorciatoia in qualsiasi app e incollare il testo dove si trova il cursore, macOS richiede il permesso Accessibilità. Attiva Dillo nell'elenco che si apre, poi torna qui.") {
            PermissionCard(symbol: "accessibility", title: "Permesso Accessibilità", granted: controller.axGranted) {
                Permissions.promptAccessibility()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    private var tryIt: some View {
        @Bindable var controller = controller
        return StepLayout(title: "Prova subito",
                          text: "\(controller.hotkeyMode == .hold ? "Tieni premuto" : "Premi") \(controller.hotkeyKey.glyph) e di' una frase. Rilascia e guarda il testo comparire qui sotto.") {
            VStack(spacing: 14) {
                Picker("Scorciatoia", selection: $controller.hotkeyKey) {
                    ForEach(HotkeyKey.allCases) { Text("\($0.title) · \($0.glyph)").tag($0) }
                }
                .frame(width: 300)
                Group {
                    if controller.isRecording || controller.state == .transcribing {
                        if controller.partialText.isEmpty { Text("Ti ascolto…").italic().foregroundStyle(Theme.textSecondary) }
                        else { RevealText(text: controller.partialText) }
                    } else if tested, let last = controller.lastTranscriptText {
                        Label(last, systemImage: "checkmark.circle.fill").foregroundStyle(.white)
                    } else {
                        Text(controller.isReady ? "In attesa della tua voce…" : controller.state.title)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .font(.system(size: 14, design: .serif))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440, minHeight: 64)
                .padding(14)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: Navigazione

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { i in
                    Capsule().fill(i == step ? Theme.coral : Color.white.opacity(0.15))
                        .frame(width: i == step ? 18 : 6, height: 6)
                }
            }
            .animation(.snappy, value: step)
            Spacer()
            if step > 0 {
                Button("Indietro") { withAnimation(.snappy) { step -= 1 } }
                    .buttonStyle(.plain).foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, 12)
            }
            Button(step == steps - 1 ? "Inizia a usare Dillo" : "Continua") {
                if step == steps - 1 { finish() } else { withAnimation(.snappy) { step += 1 } }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Theme.surface)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Pref.onboarded)
        dismissWindow(id: "onboarding")
    }
}

private struct StepLayout<Hero: View>: View {
    let title: String
    let text: String
    @ViewBuilder var hero: () -> Hero

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)
            hero()
            VStack(spacing: 10) {
                Text(title).font(Typo.display(30))
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 460)
            }
            Spacer(minLength: 10)
        }
        .padding(.horizontal, 40)
    }
}

private struct PermissionCard: View {
    let symbol: String
    let title: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(Theme.coral)
                .frame(width: 44, height: 44)
                .background(Theme.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(granted ? "Concesso" : "Necessario per usare Dillo")
                    .font(.system(size: 12)).foregroundStyle(granted ? .green : Theme.textSecondary)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.green)
            } else {
                Button("Consenti…", action: action).buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
        .animation(.snappy, value: granted)
    }
}
