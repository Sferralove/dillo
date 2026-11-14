import AVFoundation
import AudioToolbox

/// Cattura il microfono (quello di sistema o uno scelto dall'utente) e passa i buffer al motore.
final class AudioRecorder: @unchecked Sendable {
    private var engine = AVAudioEngine()
    private var configObserver: NSObjectProtocol?
    private var isRecording = false
    /// Livello RMS normalizzato (0...1) per ogni blocco audio, per la forma d'onda.
    var onLevel: (@Sendable (Float) -> Void)?
    /// Buffer grezzo del microfono (formato nativo).
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    /// UID CoreAudio del dispositivo scelto; nil = predefinito di sistema.
    var deviceUID: String?

    func start() throws {
        isRecording = true
        do { try startEngine() } catch { isRecording = false; throw error }
    }

    func stop() {
        isRecording = false
        tearDown()
    }

    private func startEngine() throws {
        // Un motore nuovo a ogni registrazione: evita formati "vecchi" dopo un cambio di dispositivo.
        engine = AVAudioEngine()
        let input = engine.inputNode
        // Il dispositivo va impostato sempre in modo esplicito: lasciato al "predefinito", AVAudioEngine
        // continua a usare il microfono che era predefinito all'avvio di Dillo (es. dopo aver collegato le AirPods).
        let chosen = deviceUID.flatMap { AudioDevices.device(uid: $0)?.id }
        if var id = chosen ?? AudioDevices.defaultInputID, let unit = input.audioUnit {
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                 &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "AudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Il microfono selezionato non è disponibile."])
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] pcm, _ in
            guard let self else { return }
            self.onBuffer?(pcm)
            guard let ch = pcm.floatChannelData?[0], pcm.frameLength > 0 else { return }
            let n = Int(pcm.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += ch[i] * ch[i] }
            let db = 20 * log10(max(sqrt(sum / Float(n)), 1e-6))   // ~ -60 dB silenzio, 0 dB massimo
            self.onLevel?(min(max((db + 55) / 45, 0), 1))
        }
        // Se il dispositivo cambia a registrazione in corso (AirPods collegate o scollegate, profilo Bluetooth
        // che passa all'auricolare) il motore si ferma: lo ricreiamo sul microfono attuale e continuiamo.
        let current = ObjectIdentifier(engine)
        configObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange,
                                                                object: engine, queue: .main) { [weak self] _ in
            // La notifica arriva anche subito dopo aver scelto il dispositivo, a motore ancora attivo:
            // ripartiamo solo se si è davvero fermato, altrimenti si innescherebbe un ciclo di riavvii.
            guard let self, self.isRecording, ObjectIdentifier(self.engine) == current,
                  !self.engine.isRunning else { return }
            self.tearDown()
            try? self.startEngine()
        }
        engine.prepare()
        do { try engine.start() } catch { tearDown(); throw error }
    }

    private func tearDown() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
