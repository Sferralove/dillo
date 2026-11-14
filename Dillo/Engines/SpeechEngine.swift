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
        // Nelle SDK più recenti il blocco di input è @Sendable. AVAudioConverter lo chiama in modo sincrono,
        // dentro `convert`, sullo stesso thread: la "sorgente" incapsula buffer e stato senza condivisione reale.
        let source = OneShotInput(buffer)
        converter.convert(to: out, error: nil) { _, status in source.next(status) }
        return out.frameLength > 0 ? out : nil
    }
}

/// Fornisce un solo buffer al convertitore, poi segnala "nessun dato".
/// `@unchecked Sendable` è sicuro: l'istanza vive solo per la durata di una chiamata sincrona a `convert`.
private final class OneShotInput: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private var fed = false

    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }

    func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        if fed { status.pointee = .noDataNow; return nil }
        fed = true
        status.pointee = .haveData
        return buffer
    }
}
