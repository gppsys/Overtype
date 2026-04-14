import AppKit
import Combine
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    private var arcAngle: CGFloat = 0
    private var spinnerTimer: Timer?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        configureStatusItem()
        observeAppState()
    }

    func refreshMenu() {
        statusItem.menu = buildMenu()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        statusItem.button?.image = idleImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.menu = buildMenu()
    }

    // MARK: - State observation

    private func observeAppState() {
        appState.$isProcessing
            .removeDuplicates()
            .sink { [weak self] isProcessing in
                if isProcessing { self?.startAnimation() }
                else            { self?.stopAnimation()  }
            }
            .store(in: &cancellables)

        // Show chunk progress ("1/3") as button title alongside the arc icon.
        appState.$processingProgress
            .sink { [weak self] progress in
                guard let self else { return }
                if let p = progress, p.total > 1 {
                    self.statusItem.button?.title = " \(p.current)/\(p.total)"
                    self.statusItem.button?.imagePosition = .imageLeft
                } else {
                    self.statusItem.button?.title = ""
                    self.statusItem.button?.imagePosition = .imageOnly
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Animation

    private func startAnimation() {
        arcAngle = 0
        spinnerTimer?.invalidate()
        spinnerTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.arcAngle = (self.arcAngle + 12).truncatingRemainder(dividingBy: 360)
                self.statusItem.button?.image = self.processingImage(angle: self.arcAngle)
            }
        }
    }

    private func stopAnimation() {
        spinnerTimer?.invalidate()
        spinnerTimer = nil
        statusItem.button?.title = ""
        statusItem.button?.image = idleImage()
        statusItem.button?.imagePosition = .imageOnly
    }

    // MARK: - Icon rendering

    /// Static OT monogram — shown when idle.
    private func idleImage() -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let text = "OT" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
            let ts = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(
                x: ((rect.width  - ts.width)  / 2).rounded(),
                y: ((rect.height - ts.height) / 2).rounded()
            ), withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// OT monogram with a spinning arc — shown while the model is running.
    /// The arc is 270° wide with rounded caps, rotates clockwise at ~30 fps.
    private func processingImage(angle: CGFloat) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)

            // OT label, sized down to leave room for the arc ring
            let text = "OT" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
            let ts = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(
                x: ((size.width  - ts.width)  / 2).rounded(),
                y: ((size.height - ts.height) / 2).rounded()
            ), withAttributes: attrs)

            // Rotating arc — 270° sweep leaves a 90° gap that implies motion
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: center,
                radius: 9.5,
                startAngle: angle,
                endAngle: angle + 270,
                clockwise: false
            )
            arc.lineWidth    = 1.5
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let currentDefaultTone = currentDefaultToneOption

        let statusMenuItem = NSMenuItem(title: "Estado: \(appState.statusMessage)", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        let defaultToneItem = NSMenuItem(title: "Tono predeterminado: \(currentDefaultTone.title)", action: nil, keyEquivalent: "")
        defaultToneItem.isEnabled = false
        menu.addItem(defaultToneItem)
        menu.addItem(.separator())

        let correctDefault = NSMenuItem(title: "Corregir selección con tono predeterminado", action: #selector(correctDefaultSelection), keyEquivalent: "")
        correctDefault.target = self
        menu.addItem(correctDefault)

        let tonesItem = NSMenuItem(title: "Corregir con tono", action: nil, keyEquivalent: "")
        let tonesMenu = NSMenu()
        for tone in ToneOption.presets {
            let toneItem = NSMenuItem(title: tone.title, action: #selector(correctWithTone(_:)), keyEquivalent: "")
            toneItem.target = self
            toneItem.representedObject = tone.id
            tonesMenu.addItem(toneItem)
        }
        menu.setSubmenu(tonesMenu, for: tonesItem)
        menu.addItem(tonesItem)

        let defaultToneSelectorItem = NSMenuItem(title: "Cambiar tono predeterminado", action: nil, keyEquivalent: "")
        let defaultToneMenu = NSMenu()
        for tone in ToneOption.presets {
            let toneItem = NSMenuItem(title: tone.title, action: #selector(setDefaultTone(_:)), keyEquivalent: "")
            toneItem.target = self
            toneItem.representedObject = tone.id
            toneItem.state = tone.id == appState.settingsStore.settings.defaultTone ? .on : .off
            defaultToneMenu.addItem(toneItem)
        }
        menu.setSubmenu(defaultToneMenu, for: defaultToneSelectorItem)
        menu.addItem(defaultToneSelectorItem)

        let paletteItem = NSMenuItem(title: "Abrir paleta de tonos", action: #selector(openTonePalette), keyEquivalent: "")
        paletteItem.target = self
        menu.addItem(paletteItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Configuracion...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let onboardingItem = NSMenuItem(title: "Onboarding y permisos", action: #selector(openOnboarding), keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc private func correctDefaultSelection() {
        appState.correctionCoordinator.correctSelection()
    }

    @objc private func correctWithTone(_ sender: NSMenuItem) {
        let tone = sender.representedObject as? String
        appState.correctionCoordinator.correctSelection(toneOverride: tone)
    }

    @objc private func setDefaultTone(_ sender: NSMenuItem) {
        guard let tone = sender.representedObject as? String else { return }
        appState.settingsStore.update { settings in
            settings.defaultTone = tone
        }
        refreshMenu()
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }

    @objc private func openOnboarding() {
        NotificationCenter.default.post(name: .openOnboardingWindow, object: nil)
    }

    @objc private func openTonePalette() {
        NotificationCenter.default.post(name: .openTonePalette, object: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private var currentDefaultToneOption: ToneOption {
        ToneOption.presets.first(where: { $0.id == appState.settingsStore.settings.defaultTone })
            ?? ToneOption(id: appState.settingsStore.settings.defaultTone, title: appState.settingsStore.settings.defaultTone)
    }
}

extension Notification.Name {
    static let openSettingsWindow  = Notification.Name("AITextCorrector.openSettingsWindow")
    static let openOnboardingWindow = Notification.Name("AITextCorrector.openOnboardingWindow")
    static let openTonePalette     = Notification.Name("AITextCorrector.openTonePalette")
    static let refreshUIState      = Notification.Name("AITextCorrector.refreshUIState")
    static let shortcutRecordingDidBegin = Notification.Name("AITextCorrector.shortcutRecordingDidBegin")
    static let shortcutRecordingDidEnd = Notification.Name("AITextCorrector.shortcutRecordingDidEnd")
}
