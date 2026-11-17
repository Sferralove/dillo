import AVFoundation
import ServiceManagement
import SwiftData
import SwiftUI

/// Impostazioni a sezioni: barra laterale a sinistra, righe "titolo · valore · Cambia" a destra.
struct SettingsView: View {
    enum Section: String, CaseIterable, Identifiable {
        case general, dictation, model, permissions, data, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: "Generale"
            case .dictation: "Dettatura"
            case .model: "Modello"
            case .permissions: "Permessi"
            case .data: "Dati e privacy"
            case .about: "Informazioni"
            }
        }
        var symbol: String {
            switch self {
            case .general: "slider.horizontal.3"
            case .dictation: "waveform"
            case .model: "cpu"
            case .permissions: "lock.shield"
            case .data: "externaldrive"
            case .about: "info.circle"
            }
        }
        static let groups: [(String, [Section])] = [
            ("Impostazioni", [.general, .dictation, .model]),
            ("Sistema", [.permissions, .data, .about]),
        ]
    }

    @State private var section: Section

    init(initialSection: Section = .general) { _section = State(initialValue: initialSection) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.stroke).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text(section.title).font(Typo.display(28))
                    content
                }
                .padding(.horizontal, 36)
                .padding(.top, 30)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(Theme.surface)
        }
        .frame(width: 780, height: 560)
        .background(Theme.graphite)
        .tint(Theme.accent)
        .preferredColorScheme(AppTheme.colorScheme)
        .toggleStyle(.switch)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Section.groups, id: \.0) { group in
                Eyebrow(group.0).padding(.leading, 10).padding(.top, 14).padding(.bottom, 4)
                ForEach(group.1) { item in
                    Button { section = item } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).frame(width: 18)
                            Text(item.title)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 13, weight: section == item ? .semibold : .regular))
                        .foregroundStyle(section == item ? Theme.ink : Theme.ink.opacity(0.7))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(section == item ? Theme.ink.opacity(0.08) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                AppMark(size: 18)
                Text("Dillo \(Bundle.main.shortVersion)")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.leading, 10).padding(.bottom, 14)
        }
        .padding(.horizontal, 10)
        .frame(width: 210)
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .general: GeneralSettings()
        case .dictation: DictationSettings()
        case .model: ModelSettings()
        case .permissions: PermissionSettings()
        case .data: DataSettings()
        case .about: AboutSettings()
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "" }
}

// MARK: - Generale

private struct GeneralSettings: View {
    @Environment(DictationController.self) private var controller
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var controller = controller
        VStack(alignment: .leading, spacing: 22) {
            SettingsGroup {
                SettingsRow(title: "Scorciatoia", detail: shortcutDetail) {
                    Menu {
                        Picker("Tasto", selection: $controller.hotkeyKey) {
                            ForEach(HotkeyKey.allCases) { Text("\($0.title) · \($0.glyph)").tag($0) }
                        }
                        .pickerStyle(.inline)
                    } label: { Text("Cambia") }
                    .menuStyle(.button).buttonStyle(.secondary).fixedSize()
                }
                SettingsRow(title: "Microfono", detail: microphoneName) {
                    // Voci esplicite invece di un Picker: l'elenco viene dal controller (aggiornato solo quando
                    // cambiano i dispositivi), così il menu non viene ricostruito mentre è aperto.
                    Menu {
                        Section("Microfono") {
                            microphoneItem("Predefinito di sistema", uid: nil)
                            ForEach(controller.inputDevices) { d in
                                microphoneItem(d.isVirtual ? "\(d.name) (virtuale)" : d.name, uid: d.uid)
                            }
                        }
                    } label: { Text("Cambia") }
                    .menuStyle(.button).buttonStyle(.secondary).fixedSize()
                    .disabled(controller.isRecording)
                }
                SettingsRow(title: "Lingua", detail: SpeechLanguage.all.first { $0.id == controller.languageID }?.name) {
                    Menu {
                        Picker("Lingua", selection: $controller.languageID) {
                            ForEach(SpeechLanguage.all) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.inline)
                    } label: { Text("Cambia") }
                    .menuStyle(.button).buttonStyle(.secondary).fixedSize()
                }
            }
            if let uid = controller.microphoneUID, !controller.inputDevices.contains(where: { $0.uid == uid }) {
                Label("Il microfono scelto non è collegato: Dillo usa quello di sistema.", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(Theme.accent)
            }
            SettingsGroup(title: "Sistema") {
                SettingsRow(title: "Apri Dillo all'avvio del Mac") {
                    Toggle("", isOn: $launchAtLogin).labelsHidden()
                        .onChange(of: launchAtLogin) { _, on in
                            do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                            catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                        }
                }
            }
        }
    }

    private var shortcutDetail: String {
        controller.hotkeyMode == .hold
            ? "Tieni premuto \(controller.hotkeyKey.glyph) e parla."
            : "Premi \(controller.hotkeyKey.glyph) per iniziare e di nuovo per fermarti."
    }

    private var microphoneName: String {
        if let uid = controller.microphoneUID, let d = controller.inputDevices.first(where: { $0.uid == uid }) { return d.name }
        return "Predefinito di sistema" + (controller.defaultInputName.map { " · \($0)" } ?? "")
    }

    private func microphoneItem(_ title: String, uid: String?) -> some View {
        Toggle(title, isOn: Binding(
            get: { controller.microphoneUID == uid },
            set: { if $0 { controller.microphoneUID = uid } }
        ))
    }
}

// MARK: - Dettatura

private struct DictationSettings: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        @Bindable var controller = controller
        VStack(alignment: .leading, spacing: 22) {
            SettingsGroup(title: "Scorciatoia") {
                SettingsRow(title: "Modalità", detail: controller.hotkeyMode == .hold
                            ? "Parla finché tieni premuto il tasto: è il modo più rapido."
                            : "Comodo per dettature lunghe: un tocco per iniziare, uno per finire.") {
                    Picker("", selection: $controller.hotkeyMode) {
                        Text("Tieni premuto").tag(HotkeyMode.hold)
                        Text("Premi e rilascia").tag(HotkeyMode.toggle)
                    }
                    .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
                SettingsRow(title: "Annulla", detail: "Interrompe la dettatura senza incollare nulla.") {
                    KeyCap(label: "esc", size: 24)
                }
            }
            SettingsGroup(title: "Comportamento") {
                SettingsRow(title: "Incolla automaticamente") {
                    Toggle("", isOn: $controller.autoPaste).labelsHidden()
                }
                SettingsRow(title: "Indicatore flottante", detail: "Mostra la voce e le parole mentre detti.") {
                    Toggle("", isOn: $controller.showHUD).labelsHidden()
                }
                SettingsRow(title: "Suoni") {
                    Toggle("", isOn: $controller.playSounds).labelsHidden()
                }
            }
            SettingsGroup(title: "Nella finestra di Dillo") {
                SettingsRow(title: "Avvia o interrompi la registrazione") { KeyCap(label: "⌘R", size: 24) }
                SettingsRow(title: "Cerca") { KeyCap(label: "⌘F", size: 24) }
                SettingsRow(title: "Impostazioni") { KeyCap(label: "⌘,", size: 24) }
            }
        }
    }
}

// MARK: - Modello

private struct ModelSettings: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 12) {
                ForEach(EngineKind.allCases) { kind in
                    EngineCard(kind: kind, selected: controller.engineKind == kind) { controller.engineKind = kind }
                }
            }
            .disabled(controller.isRecording || controller.state == .transcribing)

            SettingsGroup {
                SettingsRow(title: "Stato", detail: controller.errorMessage ?? controller.state.title) {
                    if case .downloading(let p) = controller.state {
                        ProgressView(value: p).frame(width: 140)
                    } else if controller.state == .loadingModel {
                        ProgressView().controlSize(.small)
                    } else if controller.state.isError {
                        Button("Riprova") { controller.loadEngine() }.buttonStyle(.secondary)
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }
            Text(controller.engineKind == .apple
                 ? "Apple Speech usa il modello della lingua scelta, scaricato e aggiornato da macOS."
                 : "Parakeet riconosce 25 lingue europee; la lingua scelta serve come suggerimento.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct EngineCard: View {
    let kind: EngineKind
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Theme.accent : Theme.ink.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(selected ? 0.16 : 0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(kind.title).font(.system(size: 14, weight: .semibold))
                        if kind == .apple {
                            Text("Consigliato").font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.13), in: Capsule())
                        }
                    }
                    Text(kind.subtitle).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 10)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
            }
            .padding(16)
            .background(Theme.raised.opacity(selected ? 0.9 : (hover ? 0.75 : 0.6)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Theme.accent.opacity(0.55) : Theme.stroke, lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Permessi

private struct PermissionSettings: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsGroup(footer: "Dillo chiede solo i permessi indispensabili. Puoi revocarli in qualsiasi momento in Impostazioni di Sistema → Privacy e sicurezza.") {
                SettingsRow(title: "Microfono", detail: "Per ascoltare la voce mentre detti.", symbol: "mic.fill") {
                    PermissionState(granted: controller.micGranted) {
                        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                            Task { _ = await Permissions.requestMicrophone() }
                        } else {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                        }
                    }
                }
                SettingsRow(title: "Accessibilità", detail: "Per la scorciatoia globale e per incollare il testo.", symbol: "accessibility") {
                    PermissionState(granted: controller.axGranted) {
                        Permissions.promptAccessibility()
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
        }
    }
}

private struct PermissionState: View {
    let granted: Bool
    let action: () -> Void
    var body: some View {
        if granted {
            Label("Concesso", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.green)
        } else {
            Button("Concedi…", action: action).buttonStyle(.primary)
        }
    }
}

// MARK: - Dati e privacy

private struct DataSettings: View {
    @Environment(DictationController.self) private var controller
    @State private var confirmDelete = false
    @State private var confirmModel = false
    @State private var parakeetSize = ParakeetStorage.size()

    private let retention: [(Int, String)] = [(0, "Per sempre"), (365, "1 anno"), (90, "90 giorni"), (30, "30 giorni"), (7, "7 giorni")]

    var body: some View {
        @Bindable var controller = controller
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill").font(.system(size: 20)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("La tua voce resta sul tuo Mac.").font(.system(size: 14, weight: .semibold))
                    Text("L'audio vive solo in memoria per la durata della dettatura e non viene mai inviato a server. Cronologia e dizionario sono salvati solo qui.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.accent.opacity(0.25)))

            SettingsGroup(title: "Cronologia") {
                SettingsRow(title: "Conserva", detail: retention.first { $0.0 == controller.retentionDays }?.1) {
                    Menu {
                        Picker("Conserva", selection: $controller.retentionDays) {
                            ForEach(retention, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        .pickerStyle(.inline)
                    } label: { Text("Cambia") }
                    .menuStyle(.button).buttonStyle(.secondary).fixedSize()
                }
                SettingsRow(title: "Esporta", detail: "Tutte le trascrizioni in Markdown o CSV.") {
                    HStack(spacing: 8) {
                        ForEach(HistoryExporter.Format.allCases) { f in
                            Button(f.title) {
                                let all = (try? controller.container.mainContext.fetch(FetchDescriptor<Transcript>())) ?? []
                                HistoryExporter.export(all, as: f)
                            }
                            .buttonStyle(.secondary)
                        }
                    }
                }
                SettingsRow(title: "Cartella dei dati", detail: "~/Library/Application Support/Dillo") {
                    Button("Mostra") { NSWorkspace.shared.open(URL.applicationSupportDirectory.appending(path: "Dillo")) }
                        .buttonStyle(.secondary)
                }
                SettingsRow(title: "Elimina la cronologia", detail: "Il dizionario resta invariato.") {
                    Button("Elimina…") { confirmDelete = true }.buttonStyle(.secondary)
                }
            }
            SettingsGroup(title: "Modelli scaricati") {
                SettingsRow(title: "Parakeet v3",
                            detail: parakeetSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Non scaricato") {
                    Button("Elimina…") { confirmModel = true }
                        .buttonStyle(.secondary)
                        .disabled(parakeetSize == nil || controller.engineKind == .parakeet)
                        .help(controller.engineKind == .parakeet ? "Passa ad Apple Speech per eliminare il modello" : "")
                }
            }
        }
        .confirmationDialog("Eliminare tutta la cronologia?", isPresented: $confirmDelete) {
            Button("Elimina tutte le trascrizioni", role: .destructive) { controller.deleteAllHistory() }
        } message: {
            Text("Le trascrizioni verranno eliminate definitivamente da questo Mac. Il dizionario resta invariato.")
        }
        .confirmationDialog("Eliminare il modello Parakeet?", isPresented: $confirmModel) {
            Button("Elimina modello", role: .destructive) {
                ParakeetStorage.delete()
                parakeetSize = ParakeetStorage.size()
            }
        } message: {
            Text("Libera spazio su disco. Se scegli di nuovo Parakeet, verrà riscaricato.")
        }
    }
}

// MARK: - Informazioni

private struct AboutSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                AppMark(size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dillo").font(Typo.display(24))
                    Text("Versione \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    Text("Dettatura privata, tutta sul tuo Mac.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
            }
            SettingsGroup(title: "Progetto") {
                link("Codice sorgente", "github.com/Sferralove/dillo", "https://github.com/Sferralove/dillo")
                link("Segnala un problema", "Apri una issue su GitHub", "https://github.com/Sferralove/dillo/issues/new/choose")
                link("Licenza", "MIT", "https://github.com/Sferralove/dillo/blob/main/LICENSE")
            }
            SettingsGroup(title: "Crediti") {
                link("Parakeet TDT 0.6B v3", "© NVIDIA · CC-BY-4.0", "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3")
                link("FluidAudio", "© FluidInference · Apache 2.0", "https://github.com/FluidInference/FluidAudio")
                SettingsRow(title: "Apple Speech", detail: "Riconoscimento vocale di macOS") { EmptyView() }
            }
        }
    }

    private func link(_ title: String, _ detail: String, _ url: String) -> some View {
        SettingsRow(title: title, detail: detail) {
            Button { NSWorkspace.shared.open(URL(string: url)!) } label: {
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.secondary)
            .accessibilityLabel("Apri \(title)")
        }
    }
}
