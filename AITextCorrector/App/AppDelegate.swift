import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?
    private var menuBarController: MenuBarController?
    private var shortcutManager: ShortcutManager?
    private var translateShortcutManager: ShortcutManager?
    private var servicesProvider: ServicesProvider?
    private var tonePaletteController: TonePaletteController?
    private var cancellables: Set<AnyCancellable> = []

    let appState: AppState

    override init() {
        let settingsStore = SettingsStore()
        let keychainService = KeychainService()
        let permissionManager = AccessibilityPermissionManager()
        let notificationService = NotificationService()
        let correctionService = CorrectionService(
            openAIClient: OpenAIClient(),
            promptBuilder: PromptBuilder(),
            chunkingService: ChunkingService(),
            riskAssessmentService: RiskAssessmentService(),
            notificationService: notificationService
        )
        let captureService = TextSelectionCaptureService(focusedElementReader: FocusedElementReader())
        let replacementService = TextReplacementService()
        let coordinator = CorrectionCoordinator(
            settingsStore: settingsStore,
            keychainService: keychainService,
            captureService: captureService,
            replacementService: replacementService,
            correctionService: correctionService,
            notificationService: notificationService
        )
        let appState = AppState(
            settingsStore: settingsStore,
            keychainService: keychainService,
            permissionManager: permissionManager,
            notificationService: notificationService,
            correctionCoordinator: coordinator
        )
        coordinator.attach(appState: appState)
        self.appState = appState
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(appState: appState)
        shortcutManager = ShortcutManager()
        translateShortcutManager = ShortcutManager()
        servicesProvider = ServicesProvider(coordinator: appState.correctionCoordinator)
        tonePaletteController = TonePaletteController(
            settingsStore: appState.settingsStore,
            correctionCoordinator: appState.correctionCoordinator
        )
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()

        NotificationCenter.default.addObserver(self, selector: #selector(showSettingsWindow), name: .openSettingsWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showOnboardingWindow), name: .openOnboardingWindow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showTonePalette), name: .openTonePalette, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)

        bindState()
        configureHotkey()

        Task {
            await appState.notificationService.requestAuthorizationIfNeeded()
            await appState.permissionManager.refresh()
            appState.accessibilityEnvironmentDiagnostic = appState.permissionManager.environmentDiagnostic
        }

        if ((try? appState.keychainService.loadAPIKey()) ?? "").isEmpty || !appState.permissionManager.accessibilityTrusted {
            showOnboardingWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregister()
        translateShortcutManager?.unregister()
    }

    @objc func showSettingsWindow() {
        if settingsWindowController == nil {
            let view = SettingsView(appState: appState)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "AI Text Corrector Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 820, height: 760))
            window.minSize = NSSize(width: 760, height: 680)
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        NotificationCenter.default.post(name: .refreshUIState, object: nil)
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showOnboardingWindow() {
        if onboardingWindowController == nil {
            let view = OnboardingView(appState: appState)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "Bienvenido a AI Text Corrector"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            onboardingWindowController = NSWindowController(window: window)
        }
        onboardingWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showTonePalette() {
        Task { @MainActor in
            if let selection = await appState.correctionCoordinator.captureSelectionForPalette() {
                tonePaletteController?.present(with: selection)
            }
        }
    }

    @objc private func handleAppDidBecomeActive() {
        Task {
            await appState.permissionManager.refresh()
            appState.accessibilityEnvironmentDiagnostic = appState.permissionManager.environmentDiagnostic
        }
        NotificationCenter.default.post(name: .refreshUIState, object: nil)
    }

    private func bindState() {
        appState.$isProcessing
            .sink { [weak self] _ in self?.menuBarController?.refreshTitle() }
            .store(in: &cancellables)

        appState.settingsStore.$settings
            .sink { [weak self] _ in
                self?.configureHotkey()
                self?.menuBarController?.refreshMenu()
            }
            .store(in: &cancellables)
    }

    private func configureHotkey() {
        do {
            try shortcutManager?.register(shortcut: appState.settingsStore.settings.globalShortcut) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    self?.appState.correctionCoordinator.correctSelection()
                }
            }
            appState.shortcutRegistrationMessage = shortcutWarningMessage(for: appState.settingsStore.settings.globalShortcut)
        } catch {
            appState.shortcutRegistrationMessage = error.localizedDescription
        }

        do {
            try translateShortcutManager?.register(shortcut: appState.settingsStore.settings.translateToEnglishShortcut) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    self?.appState.correctionCoordinator.translateSelectionToEnglish()
                }
            }
            appState.translateShortcutRegistrationMessage = shortcutWarningMessage(for: appState.settingsStore.settings.translateToEnglishShortcut)
        } catch {
            appState.translateShortcutRegistrationMessage = error.localizedDescription
        }
    }

    private func shortcutWarningMessage(for shortcut: Shortcut) -> String? {
        let flags = shortcut.modifierFlags
        if flags.contains(.control) && flags.contains(.option) && !flags.contains(.command) {
            return "Control + Option suele entrar en conflicto con VoiceOver en macOS. Si falla fuera de la app, prueba añadir Command o usar otra combinación."
        }
        return nil
    }
}
