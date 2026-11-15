import AVFoundation
import AudioToolbox
import Synchronization

/// Cattura il microfono (quello di sistema o uno scelto dall'utente) e passa i buffer al motore.
///
/// Il motore audio viene riusato tra una dettatura e l'altra finché il microfono resta lo stesso:
/// ricrearlo e ricollegarlo al dispositivo a ogni pressione del tasto ritarda l'avvio e taglia le prime sillabe.
/// Da fermo il microfono resta spento (nessun indicatore arancione): si riaccende solo con `start()`.
final class AudioRecorder {
    /// Livello RMS normalizzato (0...1) per ogni blocco audio, per la forma d'onda. Chiamato dal thread audio.
    var onLevel: (@Sendable (Float) -> Void)? {
        get { sink.callbacks.withLock { $0.onLevel } }
        set { sink.callbacks.withLock { $0.onLevel = newValue } }
    }
    /// Buffer grezzo del microfono (formato nativo). Chiamato dal thread audio.
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)? {
        get { sink.callbacks.withLock { $0.onBuffer } }
        set { sink.callbacks.withLock { $0.onBuffer = newValue } }
    }
    /// UID CoreAudio del dispositivo scelto; nil = predefinito di sistema.
    var deviceUID: String? { didSet { if deviceUID != oldValue { invalidate() } } }

    private let sink = TapSink()
    private var engine: AVAudioEngine?
    private var engineDevice: AudioDeviceID?
    private var configObserver: NSObjectProtocol?
    private var isRecording = false

    func start() throws {
        isRecording = true
        do { try startEngine() } catch { isRecording = false; throw error }
    }

    func stop() {
        isRecording = false
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Scarta il motore (es. microfono collegato o scollegato): il prossimo `start()` ne crea uno nuovo.
    func invalidate() {
        guard !isRecording else { return }
        discardEngine()
    }

    private func startEngine() throws {
        // Il dispositivo va impostato sempre in modo esplicito: lasciato al "predefinito", AVAudioEngine
        // continua a usare il microfono che era predefinito all'avvio di Dillo (es. dopo aver collegato le AirPods).
        let target = deviceUID.flatMap { AudioDevices.device(uid: $0)?.id } ?? AudioDevices.defaultInputID
        if engine == nil || engineDevice != target { makeEngine(device: target) }
        guard let engine else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            discardEngine()
            throw NSError(domain: "AudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Il microfono selezionato non è disponibile."])
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: format, block: sink.tapBlock)
        engine.prepare()
        do { try engine.start() } catch {
            discardEngine()
            throw error
        }
    }

    private func makeEngine(device: AudioDeviceID?) {
        discardEngine()
        let engine = AVAudioEngine()
        if var id = device, let unit = engine.inputNode.audioUnit {
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                 &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        self.engine = engine
        engineDevice = device
        // Se il dispositivo cambia (AirPods collegate o scollegate, profilo Bluetooth che passa all'auricolare):
        // da fermi scartiamo il motore; a registrazione in corso, se si è fermato, lo ricreiamo e continuiamo.
        let current = ObjectIdentifier(engine)
        configObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                                                                object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let engine = self.engine, ObjectIdentifier(engine) == current else { return }
                guard self.isRecording else { self.discardEngine(); return }
                // La notifica arriva anche subito dopo aver scelto il dispositivo, a motore ancora attivo:
                // ripartiamo solo se si è davvero fermato, altrimenti si innescherebbe un ciclo di riavvii.
                guard !engine.isRunning else { return }
                self.discardEngine()
                try? self.startEngine()
            }
        }
    }

    private func discardEngine() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        engineDevice = nil
    }
}

/// Riceve i buffer sul thread audio. I callback sono protetti da un lock perché vengono
/// impostati dal main thread mentre il thread audio li legge.
private nonisolated final class TapSink: Sendable {
    struct Callbacks {
        var onLevel: (@Sendable (Float) -> Void)?
        var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    }

    let callbacks = Mutex(Callbacks())

    var tapBlock: AVAudioNodeTapBlock {
        { [self] pcm, _ in self.deliver(pcm) }
    }

    private func deliver(_ pcm: AVAudioPCMBuffer) {
        let (onBuffer, onLevel) = callbacks.withLock { ($0.onBuffer, $0.onLevel) }
        onBuffer?(pcm)
        guard let onLevel, let ch = pcm.floatChannelData?[0], pcm.frameLength > 0 else { return }
        let n = Int(pcm.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        let db = 20 * log10(max(sqrt(sum / Float(n)), 1e-6))   // ~ -60 dB silenzio, 0 dB massimo
        onLevel(min(max((db + 55) / 45, 0), 1))
    }
}
