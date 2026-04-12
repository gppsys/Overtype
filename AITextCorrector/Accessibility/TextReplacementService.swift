import ApplicationServices
import AppKit
import Carbon.HIToolbox
import Foundation

enum TextReplacementError: LocalizedError {
    case missingContext
    case originalTextChanged
    case unsupportedReplacement
    case clipboardWriteFailed
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .missingContext:
            return "No hay contexto suficiente para reemplazar el texto en la app original."
        case .originalTextChanged:
            return "El contenido cambió antes de terminar la corrección."
        case .unsupportedReplacement:
            return "La app actual no permite reemplazo directo mediante Accessibility."
        case .clipboardWriteFailed:
            return "No se pudo copiar el texto corregido al portapapeles."
        case .pasteFailed:
            return "No se pudo pegar automáticamente el texto corregido en la app activa."
        }
    }
}

@MainActor
final class TextReplacementService {
    private let focusedElementReader = FocusedElementReader()

    func replace(_ correctedText: String, using context: AccessibilitySelectionContext) throws {
        if try replaceUsingSelectedTextAttribute(correctedText, context: context) {
            updateCaret(afterReplacingWith: correctedText, context: context)
            return
        }

        try replaceUsingFullValueRewrite(correctedText, context: context)
        updateCaret(afterReplacingWith: correctedText, context: context)
    }

    private func replaceUsingSelectedTextAttribute(_ correctedText: String, context: AccessibilitySelectionContext) throws -> Bool {
        let selectedTextResult = AXUIElementSetAttributeValue(
            context.element,
            kAXSelectedTextAttribute as CFString,
            correctedText as CFTypeRef
        )

        switch selectedTextResult {
        case .success:
            return true
        case .attributeUnsupported, .cannotComplete, .failure:
            return false
        default:
            return false
        }
    }

    private func replaceUsingFullValueRewrite(_ correctedText: String, context: AccessibilitySelectionContext) throws {
        guard let currentValue = copyStringAttribute(kAXValueAttribute as CFString, from: context.element) else {
            throw TextReplacementError.unsupportedReplacement
        }

        let nsCurrent = currentValue as NSString
        let range = NSRange(location: context.selectedRange.location, length: context.selectedRange.length)
        guard range.location + range.length <= nsCurrent.length else {
            throw TextReplacementError.unsupportedReplacement
        }

        let currentSelection = nsCurrent.substring(with: range)
        guard currentSelection == context.selectedText else {
            throw TextReplacementError.originalTextChanged
        }

        let updatedValue = nsCurrent.replacingCharacters(in: range, with: correctedText)
        let setValueResult = AXUIElementSetAttributeValue(context.element, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
        guard setValueResult == .success else { throw TextReplacementError.unsupportedReplacement }
    }

    private func updateCaret(afterReplacingWith correctedText: String, context: AccessibilitySelectionContext) {
        let newRange = CFRange(location: context.selectedRange.location + correctedText.utf16.count, length: 0)
        var mutableNewRange = newRange
        guard let rangeValue = AXValueCreate(.cfRange, &mutableNewRange) else { return }
        _ = AXUIElementSetAttributeValue(context.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
    }

    func copyToClipboard(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw TextReplacementError.clipboardWriteFailed
        }
    }

    func replaceCurrentSelectionIfStillMatching(originalSelection: String, replacementText: String) throws -> Bool {
        guard let currentContext = try? focusedElementReader.readSelection() else {
            return false
        }

        guard currentContext.selectedText == originalSelection else {
            return false
        }

        try replace(replacementText, using: currentContext)
        return true
    }

    func pasteFromClipboardIntoFocusedApp() async throws {
        try await Task.sleep(for: .milliseconds(120))
        do {
            try postPasteEvent(to: .cgSessionEventTap)
        } catch {
            try postPasteEvent(to: .cghidEventTap)
        }
    }

    private func postPasteEvent(to tap: CGEventTapLocation) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            throw TextReplacementError.pasteFailed
        }

        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand
        keyDown.post(tap: tap)
        keyUp.post(tap: tap)
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }
}
