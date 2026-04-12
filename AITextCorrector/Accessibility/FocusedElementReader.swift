import ApplicationServices
import Foundation

enum AccessibilityReaderError: LocalizedError {
    case notTrusted
    case noFocusedElement
    case unsupportedSelection

    var errorDescription: String? {
        switch self {
        case .notTrusted:
            return "La app necesita permiso de Accessibility para leer la selección activa."
        case .noFocusedElement:
            return "No se encontró un campo de texto activo."
        case .unsupportedSelection:
            return "La app activa no expone una selección de texto utilizable."
        }
    }
}

struct AccessibilitySelectionContext {
    let element: AXUIElement
    let selectedRange: CFRange
    let selectedText: String
}

struct FocusedElementReader {
    func readSelection() throws -> AccessibilitySelectionContext {
        guard AXIsProcessTrusted() else { throw AccessibilityReaderError.notTrusted }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedObject)
        guard result == .success, let focusedObject else { throw AccessibilityReaderError.noFocusedElement }

        let element = focusedObject as! AXUIElement
        guard let selectedRangeValue = copyValueAttribute(kAXSelectedTextRangeAttribute as CFString, from: element) else {
            throw AccessibilityReaderError.unsupportedSelection
        }

        var selectedRange = CFRange()
        guard AXValueGetType(selectedRangeValue) == .cfRange,
              AXValueGetValue(selectedRangeValue, .cfRange, &selectedRange),
              selectedRange.length > 0 else {
            throw AccessibilityReaderError.unsupportedSelection
        }

        let selectedText = copyStringAttribute(kAXSelectedTextAttribute as CFString, from: element)
            ?? deriveSelectionText(from: element, range: selectedRange)

        guard let selectedText,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccessibilityReaderError.unsupportedSelection
        }

        return AccessibilitySelectionContext(element: element, selectedRange: selectedRange, selectedText: selectedText)
    }

    private func deriveSelectionText(from element: AXUIElement, range: CFRange) -> String? {
        guard let fullValue = copyStringAttribute(kAXValueAttribute as CFString, from: element) else {
            return nil
        }

        let nsValue = fullValue as NSString
        let nsRange = NSRange(location: range.location, length: range.length)
        guard nsRange.location != NSNotFound,
              nsRange.location >= 0,
              nsRange.length > 0,
              nsRange.location + nsRange.length <= nsValue.length else {
            return nil
        }

        return nsValue.substring(with: nsRange)
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func copyValueAttribute(_ attribute: CFString, from element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as! AXValue?
    }
}
