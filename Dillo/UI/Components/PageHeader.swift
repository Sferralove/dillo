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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    heading
                    Spacer(minLength: 12)
                    if let search { SearchField(text: search, prompt: searchPrompt) }
                    DictationPill()
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        heading
                        Spacer(minLength: 8)
                        DictationPill()
                    }
                    if let search { SearchField(text: search, prompt: searchPrompt, expands: true) }
                }
                VStack(alignment: .leading, spacing: 16) {
                    heading
                    DictationPill()
                    if let search { SearchField(text: search, prompt: searchPrompt, expands: true) }
                }
            }
            accessory()
            LivePreview()
        }
        .padding(.horizontal, 36)
        .padding(.top, 34)
        .padding(.bottom, 18)
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Typo.pageTitle).fixedSize(horizontal: true, vertical: false)
            if let subtitle {
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
            }
        }
        .layoutPriority(1)
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
    var expands = false
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
                    .accessibilityLabel("Cancella ricerca")
            }
        }
        .padding(.horizontal, 11)
        .frame(minWidth: expands ? 0 : 220, maxWidth: expands ? .infinity : 220)
        .frame(height: 34)
        .background(Theme.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(focused ? Theme.accent.opacity(0.6) : Theme.stroke))
        .background(Button("") { focused = true }.keyboardShortcut("f").hidden())
    }
}

/// Azione di dettatura sempre esplicita, distinta dalla scorciatoia globale.
struct DictationPill: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        HStack(spacing: 12) {
            if controller.isRecording, let started = controller.recordingStartedAt {
                LevelMeter(level: controller.level, active: true, bars: 14, barWidth: 2.5, spacing: 2.5, maxHeight: 18)
                TimelineView(.periodic(from: started, by: 1)) { ctx in
                    Text(Duration.seconds(ctx.date.timeIntervalSince(started)).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
            } else if controller.isReady {
                HStack(spacing: 7) {
                    Text(controller.hotkeyMode == .hold ? "Tieni premuto" : "Premi")
                    KeyCap(label: controller.hotkeyKey.glyph, size: 22)
                    Text("ovunque")
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            } else {
                HStack(spacing: 7) {
                    if !controller.state.isError { ProgressView().controlSize(.small) }
                    Text(stateLabel)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(controller.state.isError ? Theme.accent : Theme.textSecondary)
            }

            Button {
                controller.state.isError ? controller.dismissError() : controller.toggleFromApp()
            } label: {
                Image(systemName: controller.isRecording ? "stop.fill" : (controller.state.isError ? "arrow.clockwise" : "mic.fill"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(controller.isRecording ? .white : Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(controller.isRecording ? Theme.accent : Theme.accent.opacity(0.14), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(controller.isRecording ? 0 : 0.35)))
                    .shadow(color: Theme.accent.opacity(controller.isRecording ? 0.5 : 0), radius: 10)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!(controller.isReady || controller.isRecording || controller.state.isError))
            .help(controller.isRecording ? "Interrompi (⌘R)" : "Detta qui: il testo va nella cronologia (⌘R)")
            .accessibilityLabel(controller.isRecording ? "Interrompi dettatura" : "Avvia dettatura")
        }
        .padding(.leading, 16)
        .padding(.trailing, 5)
        .frame(height: 46)
        .background(Theme.ink.opacity(controller.isRecording ? 0.06 : 0.035), in: Capsule())
        .overlay(Capsule().strokeBorder(controller.isRecording ? Theme.accent.opacity(0.45) : Theme.stroke))
        .fixedSize()
        .animation(.snappy(duration: 0.25), value: controller.isRecording)
    }

    private var stateLabel: String {
        switch controller.state {
        case .downloading(let p): "Scarico il modello · \(Int(p * 100))%"
        case .loadingModel: "Preparo il motore…"
        case .transcribing: "Trascrivo…"
        case .error: "Errore · riprova"
        default: ""
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
                    Circle().fill(Theme.accent).frame(width: 6, height: 6).padding(.top, 6)
                    Group {
                        if controller.micSilent {
                            Text("Il microfono non sente nulla: controlla il microfono scelto nelle Impostazioni.")
                                .foregroundStyle(Theme.accent)
                        } else if controller.partialText.isEmpty {
                            Text("Ti ascolto…").italic()
                        } else {
                            RevealText(text: controller.partialText)
                        }
                    }
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink.opacity(controller.partialText.isEmpty ? 0.5 : 0.9))
                        .lineLimit(2)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent.opacity(0.25)))
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let lang = controller.languageSuggestion {
                LanguageBanner(language: lang)
            } else if let error = controller.errorMessage {
                Banner(symbol: "exclamationmark.triangle", text: error, action: ("Riprova", { controller.loadEngine() }))
            } else if AppMode.isDemo {
                EmptyView()
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
            Image(systemName: symbol).foregroundStyle(Theme.accent)
            Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.ink.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action.0, action: action.1).buttonStyle(.primary)
        }
        .padding(12)
        .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent.opacity(0.25)))
    }
}

/// "Stai parlando inglese?" — proposta di cambiare lingua.
struct LanguageBanner: View {
    let language: SpeechLanguage
    @Environment(DictationController.self) private var controller

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe").foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Stai parlando \(language.localizedName)?").font(.system(size: 13, weight: .semibold))
                Text("Le ultime dettature sembrano in \(language.localizedName). Passa a questa lingua per un riconoscimento più preciso.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Non ora") { controller.dismissLanguageSuggestion() }.buttonStyle(.secondary)
            Button("Passa a \(language.name)") { controller.acceptLanguageSuggestion() }
                .buttonStyle(.primary)
        }
        .padding(12)
        .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent.opacity(0.25)))
    }
}
