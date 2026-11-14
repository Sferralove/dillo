import AVFoundation
import AudioToolbox

/// Cattura il microfono (quello di sistema o uno scelto dall'utente) e passa i buffer al motore.
final class AudioRecorder: @unchecked Sendable {
    private var engine = AVAudioEngine()
    /// Livello RMS normalizzato (0...1) per ogni blocco audio, per la forma d'onda.
    var onLevel: (@Sendable (Float) -> Void)?
    /// Buffer grezzo del microfono (formato nativo).
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    /// UID CoreAudio del dispositivo scelto; nil = predefinito di sistema.
    var deviceUID: String?

    func start() throws {
        // Un motore nuovo a ogni registrazione: evita formati "vecchi" dopo un cambio di dispositivo.
        engine = AVAudioEngine()
        let input = engine.inputNode
        if let uid = deviceUID, let device = AudioDevices.device(uid: uid), let unit = input.audioUnit {
            var id = device.id
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
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
