import AppKit
import Carbon.HIToolbox
import Foundation

enum ShortcutManagerError: LocalizedError {
    case installHandlerFailed(OSStatus)
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .installHandlerFailed(let status):
            return "No se pudo instalar el listener del shortcut global. Código: \(status)"
        case .registrationFailed(let status):
            return "No se pudo registrar el shortcut global. Puede estar en conflicto con otro atajo del sistema o de otra app. Código: \(status)"
        }
    }
}

@MainActor
final class ShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeySignature = OSType(0x41495443) // "AITC"
    private let hotKeyIdentifier: UInt32
    private var action: (() -> Void)?

    init() {
        self.hotKeyIdentifier = Self.allocateIdentifier()
    }

    func register(shortcut: Shortcut, action: @escaping () -> Void) throws {
        self.action = action
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr,
                  let userData,
                  hotKeyID.signature == OSType(0x41495443) else {
                return OSStatus(eventNotHandledErr)
            }

            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            guard hotKeyID.id == manager.hotKeyIdentifier else {
                return OSStatus(eventNotHandledErr)
            }
            manager.action?()
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)
        guard installStatus == noErr else {
            throw ShortcutManagerError.installHandlerFailed(installStatus)
        }

        let identifier = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)
        let registrationStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registrationStatus == noErr else {
            throw ShortcutManagerError.registrationFailed(registrationStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private static var nextIdentifier: UInt32 = 1

    private static func allocateIdentifier() -> UInt32 {
        defer { nextIdentifier += 1 }
        return nextIdentifier
    }
}
