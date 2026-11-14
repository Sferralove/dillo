import AVFoundation
import ApplicationServices

enum Permissions {
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static func promptAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static var microphoneGranted: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
