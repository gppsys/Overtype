import AppKit
import SwiftUI

@MainActor
final class TonePaletteController {
    private let settingsStore: SettingsStore
    private let correctionCoordinator: CorrectionCoordinator
    private var panel: TonePalettePanel?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var currentSelection: CapturedSelection?

    init(settingsStore: SettingsStore, correctionCoordinator: CorrectionCoordinator) {
        self.settingsStore = settingsStore
        self.correctionCoordinator = correctionCoordinator
    }

    func present(with selection: CapturedSelection) {
        currentSelection = selection

        let rootView = TonePaletteView(
            settingsStore: settingsStore,
            selectionPreview: makeSelectionPreview(from: selection.text),
            onUseDefault: { [weak self] in
                guard let self, let selection = self.currentSelection else { return }
                self.dismiss()
                self.correctionCoordinator.correctCapturedSelection(selection)
            },
            onSelectTone: { [weak self] tone in
                guard let self, let selection = self.currentSelection else { return }
                self.dismiss()
                self.correctionCoordinator.correctCapturedSelection(selection, toneOverride: tone)
            },
            onSetDefaultTone: { [weak self] tone in
                self?.settingsStore.update { settings in
                    settings.defaultTone = tone
                }
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )

        let host = NSHostingController(rootView: rootView)
        let panel = self.panel ?? TonePalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = host
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        position(panel: panel, near: NSEvent.mouseLocation)
        panel.orderFrontRegardless()
        self.panel = panel

        installDismissMonitors()
    }

    func dismiss() {
        panel?.orderOut(nil)
        currentSelection = nil
        removeDismissMonitors()
    }

    private func position(panel: NSPanel, near mouseLocation: NSPoint) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let panelSize = panel.frame.size

        var origin = NSPoint(
            x: mouseLocation.x - 24,
            y: mouseLocation.y - panelSize.height - 16
        )

        origin.x = min(max(origin.x, visibleFrame.minX + 12), visibleFrame.maxX - panelSize.width - 12)
        origin.y = max(origin.y, visibleFrame.minY + 12)
        if origin.y + panelSize.height > visibleFrame.maxY - 12 {
            origin.y = visibleFrame.maxY - panelSize.height - 12
        }

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func makeSelectionPreview(from text: String) -> String {
        let compact = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 140 { return compact }
        let endIndex = compact.index(compact.startIndex, offsetBy: 140)
        return String(compact[..<endIndex]) + "..."
    }
}

private final class TonePalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
