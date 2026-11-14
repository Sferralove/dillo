import AVFoundation

enum ModelLoadPhase: Sendable {
    case downloading(Double)   // 0...1
    case loading
}

/// Un motore di trascrizione in streaming: riceve l'audio mentre parli e restituisce il testo finale al rilascio.
protocol SpeechEngine: AnyObject, Sendable {
    var displayName: String { get }
    func prepare(onPhase: @escaping @Sendable (ModelLoadPhase) -> Void) async throws
    func begin(vocabulary: [String], onPartial: @escaping @Sendable (String) -> Void)
    func append(_ buffer: AVAudioPCMBuffer)
    func finish() async throws -> String
}

/// Converte i buffer del microfono in un formato di destinazione, riusando il convertitore.
final class PCMConverter: @unchecked Sendable {
    let target: AVAudioFormat
    private var converter: AVAudioConverter?

    init(target: AVAudioFormat) { self.target = target }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == target { return buffer.copy() as? AVAudioPCMBuffer }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
        }
        guard let converter else { return nil }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var fed = false
        converter.convert(to: out, error: nil) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true; status.pointee = .haveData; return buffer
        }
        return out.frameLength > 0 ? out : nil
    }
}
