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

    // MARK: - Present with selection

    func present(with selection: CapturedSelection) {
        currentSelection = selection
        showPanel(mode: .selection(text: selection.text))
    }

    // MARK: - Present for direct text input (no prior selection needed)

    func presentForDirectInput() {
        currentSelection = nil
        showPanel(mode: .directInput)
    }

    // MARK: - Dismiss

    func dismiss() {
        panel?.orderOut(nil)
        currentSelection = nil
        removeDismissMonitors()
    }

    // MARK: - Shared panel setup

    private func showPanel(mode: PaletteMode) {
        let rootView = TonePaletteView(
            settingsStore: settingsStore,
            mode: mode,
            onSelectTone: { [weak self] toneId, action in
                guard let self, let selection = self.currentSelection else { return }
                self.dismiss()
                if action == .correct {
                    self.correctionCoordinator.correctCapturedSelection(selection, toneOverride: toneId)
                } else {
                    self.correctionCoordinator.translateCapturedSelectionToEnglish(selection, toneOverride: toneId)
                }
            },
            onProcessText: { [weak self] text, toneOverride, action in
                guard let self else { throw CancellationError() }
                return try await self.correctionCoordinator.processText(text, toneOverride: toneOverride, action: action)
            },
            onSetDefaultTone: { [weak self] toneId in
                self?.settingsStore.update { settings in
                    settings.defaultTone = toneId
                }
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )

        let host = NSHostingController(rootView: rootView)

        if panel == nil {
            panel = TonePalettePanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        }

        let panel = self.panel!
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

        installDismissMonitors()
    }

    // MARK: - Positioning

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

    // MARK: - Dismiss monitors

    private func installDismissMonitors() {
        removeDismissMonitors()

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = keyMonitor   { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}

// MARK: - Panel subclass

private final class TonePalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
