import CoreAudio
import Foundation

/// Dispositivi di ingresso audio del sistema (inclusi quelli virtuali come Krisp o BlackHole).
nonisolated struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let isVirtual: Bool
}

nonisolated enum AudioDevices {
    static func inputs() -> [AudioInputDevice] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard inputChannels(id) > 0, let uid = string(id, kAudioDevicePropertyDeviceUID),
                  !isPrivateAggregate(uid: uid),
                  let name = string(id, kAudioObjectPropertyName) else { return nil }
            let transport = uint32(id, kAudioDevicePropertyTransportType) ?? 0
            let virtual = transport == kAudioDeviceTransportTypeVirtual || transport == kAudioDeviceTransportTypeAggregate
            return AudioInputDevice(id: id, uid: uid, name: name, isVirtual: virtual)
        }
        .sorted { ($0.isVirtual ? 1 : 0, $0.name) < ($1.isVirtual ? 1 : 0, $1.name) }
    }

    static func device(uid: String) -> AudioInputDevice? { inputs().first { $0.uid == uid } }

    /// Dispositivi aggregati che CoreAudio crea da sé dentro un processo (es. `CADefaultDeviceAggregate-<pid>-<n>`,
    /// generato da AVAudioEngine): non sono microfoni veri e cambiano a ogni avvio, quindi non vanno proposti.
    static func isPrivateAggregate(uid: String) -> Bool {
        uid.hasPrefix("CADefaultDeviceAggregate")
    }

    /// Chiama `handler` sul main thread quando si collega o scollega un dispositivo o cambia il microfono predefinito.
    /// Restituisce un oggetto da tenere in vita finché serve l'ascolto.
    static func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> AnyObject {
        DeviceChangeObserver(handler)
    }

    /// Microfono predefinito di sistema in questo momento (cambia, ad esempio, quando colleghi le AirPods).
    static var defaultInputID: AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    static var defaultInputName: String? { defaultInputID.flatMap { string($0, kAudioObjectPropertyName) } }

    private static func inputChannels(_ id: AudioDeviceID) -> Int {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                              mScope: kAudioDevicePropertyScopeInput,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func uint32(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }
}

/// Ascolta le proprietà di sistema di CoreAudio (elenco dispositivi e ingresso predefinito).
/// `@unchecked Sendable`: tutte le proprietà sono costanti dopo `init`, e il blocco salta sul main actor.
private nonisolated final class DeviceChangeObserver: @unchecked Sendable {
    private var addresses: [AudioObjectPropertyAddress] = [
        .init(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
              mElement: kAudioObjectPropertyElementMain),
        .init(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal,
              mElement: kAudioObjectPropertyElementMain),
    ]
    private let block: AudioObjectPropertyListenerBlock

    init(_ handler: @escaping @MainActor @Sendable () -> Void) {
        block = { _, _ in Task { @MainActor in handler() } }
        for i in addresses.indices {
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addresses[i], .main, block)
        }
    }

    deinit {
        for i in addresses.indices {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addresses[i], .main, block)
        }
    }
}
