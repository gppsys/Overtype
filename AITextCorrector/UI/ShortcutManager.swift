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
    private let hotKeyID = OSType(1_337)
    private var action: (() -> Void)?

    func register(shortcut: Shortcut, action: @escaping () -> Void) throws {
        self.action = action
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event else { return noErr }
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
                  hotKeyID.signature == OSType(1_337) else {
                return noErr
            }

            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            manager.action?()
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)
        guard installStatus == noErr else {
            throw ShortcutManagerError.installHandlerFailed(installStatus)
        }

        let identifier = EventHotKeyID(signature: hotKeyID, id: 1)
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
}
