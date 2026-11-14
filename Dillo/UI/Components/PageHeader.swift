import AVFoundation
import SwiftUI

/// Intestazione comune delle pagine: titolo serif, sottotitolo, ricerca opzionale e controllo di dettatura.
struct PageHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    var search: Binding<String>?
    var searchPrompt = "Cerca"
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Typo.pageTitle)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 20)
                if let search { SearchField(text: search, prompt: searchPrompt) }
                DictationPill()
            }
            accessory()
            LivePreview()
        }
        .padding(.horizontal, 36)
        .padding(.top, 34)
        .padding(.bottom, 18)
    }
}

extension PageHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, search: Binding<String>? = nil, searchPrompt: String = "Cerca") {
        self.init(title: title, subtitle: subtitle, search: search, searchPrompt: searchPrompt) { EmptyView() }
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 11)
        .frame(width: 240, height: 32)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(focused ? Theme.coral.opacity(0.6) : Theme.stroke))
        .background(Button("") { focused = true }.keyboardShortcut("f").hidden())
    }
}

/// Controllo compatto di dettatura: pulsante, forma d'onda e timer.
struct DictationPill: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        HStack(spacing: 10) {
            Button {
                controller.state.isError ? controller.dismissError() : controller.toggleFromApp()
            } label: {
                Image(systemName: controller.isRecording ? "stop.fill" : (controller.state.isError ? "arrow.clockwise" : "mic.fill"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(controller.isRecording ? .white : Theme.coral)
                    .frame(width: 30, height: 30)
                    .background(controller.isRecording ? Theme.coral : Theme.coral.opacity(0.15), in: Circle())
                    .shadow(color: Theme.coral.opacity(controller.isRecording ? 0.6 : 0), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(!(controller.isReady || controller.isRecording || controller.state.isError))
            .help(controller.isRecording ? "Interrompi registrazione (⌘R)" : "Avvia registrazione (⌘R)")

            LevelMeter(level: controller.level, active: controller.isRecording, bars: 18, barWidth: 2.5, spacing: 2.5, maxHeight: 20)

            Group {
                if controller.isRecording, let started = controller.recordingStartedAt {
                    TimelineView(.periodic(from: started, by: 1)) { ctx in
                        Text(Duration.seconds(ctx.date.timeIntervalSince(started)).formatted(.time(pattern: .minuteSecond)))
                            .foregroundStyle(Theme.coral)
                    }
                } else {
                    HStack(spacing: 5) {
                        if controller.state == .transcribing || controller.state == .loadingModel {
                            ProgressView().controlSize(.mini)
                        }
                        Text(stateLabel).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .font(.system(size: 11.5, weight: .medium).monospacedDigit())
            .frame(minWidth: 54, alignment: .leading)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .frame(height: 40)
        .background(Color.white.opacity(0.04), in: Capsule())
        .overlay(Capsule().strokeBorder(controller.isRecording ? Theme.coral.opacity(0.45) : Theme.stroke))
        .animation(.easeOut(duration: 0.2), value: controller.isRecording)
    }

    private var stateLabel: String {
        switch controller.state {
        case .idle: controller.hotkeyKey.glyph
        case .downloading(let p): "\(Int(p * 100))%"
        case .loadingModel: "Avvio"
        case .transcribing: "Trascrivo"
        case .recording: ""
        case .error: "Errore"
        }
    }
}

/// Riga con l'anteprima live mentre registri dalla finestra, o con l'ultimo avviso.
struct LivePreview: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        Group {
            if controller.isRecording || controller.state == .transcribing {
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Theme.coral).frame(width: 6, height: 6).padding(.top, 6)
                    Group {
                        if controller.micSilent {
                            Text("Il microfono non sente nulla: controlla il microfono scelto nelle Impostazioni.")
                                .foregroundStyle(Theme.coral)
                        } else if controller.partialText.isEmpty {
                            Text("Ti ascolto…").italic()
                        } else {
                            RevealText(text: controller.partialText)
                        }
                    }
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(.white.opacity(controller.partialText.isEmpty ? 0.5 : 0.9))
                        .lineLimit(2)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Theme.coral.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.coral.opacity(0.25)))
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let lang = controller.languageSuggestion {
                LanguageBanner(language: lang)
            } else if let error = controller.errorMessage {
                Banner(symbol: "exclamationmark.triangle", text: error, action: ("Riprova", { controller.loadEngine() }))
            } else if !controller.micGranted {
                Banner(symbol: "mic.slash",
                       text: "Dillo non ha accesso al microfono. Consentilo in Impostazioni di Sistema → Privacy e sicurezza → Microfono.",
                       action: ("Apri…", {
                           if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                               Task { _ = await Permissions.requestMicrophone() }
                           } else {
                               NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                           }
                       }))
            } else if !controller.axGranted {
                Banner(symbol: "lock.trianglebadge.exclamationmark",
                       text: "Concedi il permesso Accessibilità per usare la scorciatoia globale e incollare nelle altre app.",
                       action: ("Concedi…", { Permissions.promptAccessibility() }))
            }
        }
        .animation(.spring(duration: 0.3), value: controller.isRecording)
    }
}

struct Banner: View {
    let symbol: String
    let text: String
    let action: (String, () -> Void)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.coral)
            Text(text).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action.0, action: action.1).buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(12)
        .background(Theme.coral.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.coral.opacity(0.25)))
    }
}

/// "Stai parlando inglese?" — proposta di cambiare lingua.
struct LanguageBanner: View {
    let language: SpeechLanguage
    @Environment(DictationController.self) private var controller

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe").foregroundStyle(Theme.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text("Stai parlando \(language.localizedName)?").font(.system(size: 13, weight: .semibold))
                Text("Le ultime dettature sembrano in \(language.localizedName). Passa a questa lingua per un riconoscimento più preciso.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Non ora") { controller.dismissLanguageSuggestion() }.controlSize(.small)
            Button("Passa a \(language.name)") { controller.acceptLanguageSuggestion() }
                .buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(12)
        .background(Theme.coral.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.coral.opacity(0.25)))
    }
}
