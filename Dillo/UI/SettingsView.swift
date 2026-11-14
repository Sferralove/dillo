import ServiceManagement
import SwiftData
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Generale", systemImage: "gearshape") { GeneralSettings() }
            Tab("Scorciatoia", systemImage: "keyboard") { ShortcutSettings() }
            Tab("Modello", systemImage: "cpu") { ModelSettings() }
            Tab("Dati", systemImage: "externaldrive") { DataSettings() }
        }
        .frame(width: 560)
        .tint(Theme.coral)
        .preferredColorScheme(.dark)
    }
}

private struct GeneralSettings: View {
    @Environment(DictationController.self) private var controller
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var micStatus = AVCaptureDeviceStatus.current

    var body: some View {
        @Bindable var controller = controller
        Form {
            Section("Microfono") {
                Picker("Ingresso", selection: $controller.microphoneUID) {
                    Text("Predefinito di sistema\(AudioDevices.defaultInputName.map { " (\($0))" } ?? "")").tag(String?.none)
                    let devices = AudioDevices.inputs()
                    let physical = devices.filter { !$0.isVirtual }
                    let virtual = devices.filter(\.isVirtual)
                    if !physical.isEmpty {
                        Divider()
                        ForEach(physical) { Text($0.name).tag(Optional($0.uid)) }
                    }
                    if !virtual.isEmpty {
                        Divider()
                        Section("Dispositivi virtuali") {
                            ForEach(virtual) { Text($0.name).tag(Optional($0.uid)) }
                        }
                    }
                }
                .disabled(controller.isRecording)
                if let uid = controller.microphoneUID, AudioDevices.device(uid: uid) == nil {
                    Label("Il microfono scelto non è collegato: Dillo userà quello di sistema.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(Theme.coral)
                }
            }
            Section("Dettatura") {
                Toggle("Incolla automaticamente nell'app attiva", isOn: $controller.autoPaste)
                Toggle("Mostra l'indicatore flottante durante la dettatura", isOn: $controller.showHUD)
                Toggle("Suoni di inizio e fine dettatura", isOn: $controller.playSounds)
            }
            Section("Sistema") {
                Toggle("Apri Dillo all'avvio del Mac", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                        catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
            }
            Section("Permessi") {
                PermissionRow(title: "Accessibilità", detail: "Scorciatoia globale e incolla automatico",
                              granted: controller.axGranted) { Permissions.promptAccessibility() }
                PermissionRow(title: "Microfono", detail: "Registrazione della voce",
                              granted: micStatus == .granted) {
                    Task { _ = await Permissions.requestMicrophone(); micStatus = .current }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
    }
}

private enum AVCaptureDeviceStatus {
    case granted, other
    static var current: Self { Permissions.microphoneGranted ? .granted : .other }
}

private struct PermissionRow: View {
    let title: String, detail: String, granted: Bool, action: () -> Void
    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : Theme.coral)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted { Button("Concedi…", action: action) }
            else { Text("Concesso").foregroundStyle(.secondary) }
        }
    }
}

private struct ShortcutSettings: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        @Bindable var controller = controller
        Form {
            Section {
                Picker("Tasto", selection: $controller.hotkeyKey) {
                    ForEach(HotkeyKey.allCases) { key in
                        Text("\(key.title)  ·  \(key.glyph)").tag(key)
                    }
                }
                Picker("Modalità", selection: $controller.hotkeyMode) {
                    ForEach(HotkeyMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Scorciatoia globale")
            } footer: {
                Text(controller.hotkeyMode == .hold
                     ? "Tieni premuto \(controller.hotkeyKey.glyph) mentre parli e rilascialo per incollare il testo nell'app in cui stai scrivendo."
                     : "Premi \(controller.hotkeyKey.glyph) una volta per iniziare a dettare e di nuovo per fermarti e incollare.")
                    .foregroundStyle(.secondary)
            }
            Section("Nella finestra di Dillo") {
                LabeledContent("Avvia / interrompi registrazione", value: "⌘R")
                LabeledContent("Impostazioni", value: "⌘,")
            }
        }
        .formStyle(.grouped)
        .frame(height: 400)
    }
}

private struct ModelSettings: View {
    @Environment(DictationController.self) private var controller

    var body: some View {
        @Bindable var controller = controller
        Form {
            Section("Motore di trascrizione") {
                ForEach(EngineKind.allCases) { kind in
                    EngineOption(kind: kind, selected: controller.engineKind == kind) {
                        controller.engineKind = kind
                    }
                }
                .disabled(controller.isRecording || controller.state == .transcribing)
            }
            Section {
                Picker("Lingua", selection: $controller.languageID) {
                    ForEach(SpeechLanguage.all) { Text($0.name).tag($0.id) }
                }
                LabeledContent("Stato") {
                    HStack(spacing: 8) {
                        if case .downloading(let p) = controller.state {
                            ProgressView(value: p).frame(width: 120)
                        } else if controller.state == .loadingModel {
                            ProgressView().controlSize(.small)
                        }
                        Text(controller.errorMessage ?? controller.state.title)
                            .foregroundStyle(controller.state.isError ? .red : .secondary)
                            .lineLimit(2)
                        if controller.state.isError {
                            Button("Riprova") { controller.loadEngine() }
                        }
                    }
                }
            } footer: {
                Text(controller.engineKind == .apple
                     ? "Apple Speech usa il modello della lingua scelta, scaricato e gestito da macOS."
                     : "Parakeet riconosce le 25 lingue europee; la lingua scelta serve come suggerimento.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 400)
    }
}

private struct EngineOption: View {
    let kind: EngineKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 18))
                    .frame(width: 32, height: 32)
                    .background(Theme.coral.opacity(selected ? 0.2 : 0.06), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(selected ? Theme.coral : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title).font(.system(size: 13, weight: .semibold))
                    Text(kind.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.coral : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DataSettings: View {
    @Environment(DictationController.self) private var controller
    @State private var confirmDelete = false
    @State private var confirmModel = false
    @State private var parakeetSize = ParakeetStorage.size()

    var body: some View {
        @Bindable var controller = controller
        Form {
            Section {
                Picker("Conserva la cronologia", selection: $controller.retentionDays) {
                    Text("Per sempre").tag(0)
                    Text("1 anno").tag(365)
                    Text("90 giorni").tag(90)
                    Text("30 giorni").tag(30)
                    Text("7 giorni").tag(7)
                }
            } header: {
                Text("Cronologia")
            } footer: {
                Text("Trascrizioni e dizionario sono salvati solo su questo Mac. L'audio non viene mai registrato su disco.")
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Text("Esporta tutta la cronologia")
                    Spacer()
                    ForEach(HistoryExporter.Format.allCases) { f in
                        Button(f.title) {
                            let all = (try? controller.container.mainContext.fetch(FetchDescriptor<Transcript>())) ?? []
                            HistoryExporter.export(all, as: f)
                        }
                    }
                }
                HStack {
                    Text("Cartella dei dati")
                    Spacer()
                    Button("Mostra nel Finder") {
                        NSWorkspace.shared.open(URL.applicationSupportDirectory.appending(path: "Dillo"))
                    }
                }
                HStack {
                    Text("Elimina tutta la cronologia")
                    Spacer()
                    Button("Elimina…", role: .destructive) { confirmDelete = true }
                }
            }
            Section("Modelli scaricati") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Parakeet v3")
                        Text(parakeetSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "Non scaricato")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Elimina…") { confirmModel = true }
                        .disabled(parakeetSize == nil || controller.engineKind == .parakeet)
                        .help(controller.engineKind == .parakeet ? "Passa ad Apple Speech per eliminare il modello" : "")
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 440)
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
