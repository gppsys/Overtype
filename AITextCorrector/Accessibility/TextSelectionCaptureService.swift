import AppKit
import Carbon.HIToolbox
import Foundation

enum TextCaptureError: LocalizedError {
    case noSelection
    case clipboardTimeout
    case clipboardUnavailable

    var errorDescription: String? {
        switch self {
        case .noSelection:
            return "No hay texto seleccionado."
        case .clipboardTimeout:
            return "No se pudo capturar la selección actual por portapapeles."
        case .clipboardUnavailable:
            return "No se pudo acceder al portapapeles del sistema."
        }
    }
}

struct ClipboardSnapshot {
    struct Item {
        let types: [(NSPasteboard.PasteboardType, Data)]
    }

    let items: [Item]
}

@MainActor
final class TextSelectionCaptureService {
    private let focusedElementReader: FocusedElementReader
    private(set) var lastDiagnosticReport: CaptureDiagnosticReport?

    init(focusedElementReader: FocusedElementReader) {
        self.focusedElementReader = focusedElementReader
    }

    func captureSelectedText() async throws -> CapturedSelection {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName
        let appBundleIdentifier = frontmostApp?.bundleIdentifier

        do {
            let accessibilitySelection = try focusedElementReader.readSelection()
            lastDiagnosticReport = CaptureDiagnosticReport(
                appName: appName,
                usedAccessibility: true,
                accessibilityDetail: "Selection read successfully via Accessibility.",
                usedClipboardFallback: false,
                clipboardDetail: "Clipboard fallback not needed.",
                finalStatus: "Success via Accessibility."
            )
            return CapturedSelection(text: accessibilitySelection.selectedText, accessibilityContext: accessibilitySelection, appBundleIdentifier: appBundleIdentifier)
        } catch {
            let accessibilityMessage = error.localizedDescription

            do {
                let text = try await captureViaClipboardShortcut()
                lastDiagnosticReport = CaptureDiagnosticReport(
                    appName: appName,
                    usedAccessibility: false,
                    accessibilityDetail: accessibilityMessage,
                    usedClipboardFallback: true,
                    clipboardDetail: "Clipboard fallback captured the selected text successfully.",
                    finalStatus: "Success via clipboard fallback."
                )
                return CapturedSelection(text: text, accessibilityContext: nil, appBundleIdentifier: appBundleIdentifier)
            } catch {
                lastDiagnosticReport = CaptureDiagnosticReport(
                    appName: appName,
                    usedAccessibility: false,
                    accessibilityDetail: accessibilityMessage,
                    usedClipboardFallback: true,
                    clipboardDetail: error.localizedDescription,
                    finalStatus: "Capture failed."
                )
                throw error
            }
        }
    }

    func captureFromServicePasteboard(_ pasteboard: NSPasteboard) throws -> CapturedSelection {
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextCaptureError.noSelection
        }
        return CapturedSelection(text: text, accessibilityContext: nil, appBundleIdentifier: nil)
    }

    private func captureViaClipboardShortcut() async throws -> String {
        let initialDelays: [UInt64] = [120, 260]
        var lastError: Error = TextCaptureError.clipboardTimeout

        for initialDelay in initialDelays {
            do {
                return try await captureViaClipboardAttempt(initialDelayMilliseconds: initialDelay)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private func captureViaClipboardAttempt(initialDelayMilliseconds: UInt64) async throws -> String {
        guard let snapshot = snapshotPasteboard() else { throw TextCaptureError.clipboardUnavailable }
        let pasteboard = NSPasteboard.general
        let sentinel = UUID().uuidString

        pasteboard.clearContents()
        guard pasteboard.setString(sentinel, forType: .string) else {
            restorePasteboard(snapshot)
            throw TextCaptureError.clipboardUnavailable
        }

        try await Task.sleep(for: .milliseconds(initialDelayMilliseconds))
        try postKeystroke(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)

        let deadline = Date().addingTimeInterval(2.2)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(70))
            let currentValue = pasteboard.string(forType: .string) ?? ""
            guard currentValue != sentinel else { continue }
            let captured = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            restorePasteboard(snapshot)
            guard !captured.isEmpty else { throw TextCaptureError.noSelection }
            return captured
        }

        restorePasteboard(snapshot)
        throw TextCaptureError.clipboardTimeout
    }

    private func postKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw TextCaptureError.clipboardUnavailable
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func snapshotPasteboard() -> ClipboardSnapshot? {
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems?.map { item in
            ClipboardSnapshot.Item(types: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            })
        } ?? []
        return ClipboardSnapshot(items: items)
    }

    private func restorePasteboard(_ snapshot: ClipboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for item in snapshot.items {
            let pbItem = NSPasteboardItem()
            for (type, data) in item.types {
                pbItem.setData(data, forType: type)
            }
            pasteboard.writeObjects([pbItem])
        }
    }
}
