import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
        configureStatusItem()
    }

    func refreshTitle() {
        statusItem.button?.title = appState.isProcessing ? "AI..." : "AI Corrector"
    }

    func refreshMenu() {
        statusItem.menu = buildMenu()
    }

    private func configureStatusItem() {
        statusItem.button?.title = "AI Corrector"
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let currentDefaultTone = currentDefaultToneOption

        let statusItem = NSMenuItem(title: "Estado: \(appState.statusMessage)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

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
    static let openSettingsWindow = Notification.Name("AITextCorrector.openSettingsWindow")
    static let openOnboardingWindow = Notification.Name("AITextCorrector.openOnboardingWindow")
    static let openTonePalette = Notification.Name("AITextCorrector.openTonePalette")
    static let refreshUIState = Notification.Name("AITextCorrector.refreshUIState")
}
