import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage = "Listo"
    @Published var processingProgress: (current: Int, total: Int)? = nil
    @Published var lastErrorMessage: String?
    @Published var lastCaptureDiagnostic: CaptureDiagnosticReport?
    @Published var accessibilityEnvironmentDiagnostic: AccessibilityEnvironmentDiagnostic?
    @Published var shortcutRegistrationMessage: String?
    @Published var translateShortcutRegistrationMessage: String?

    let settingsStore: SettingsStore
    let keychainService: KeychainService
    let permissionManager: AccessibilityPermissionManager
    let notificationService: NotificationService
    let correctionCoordinator: CorrectionCoordinator

    init(
        settingsStore: SettingsStore,
        keychainService: KeychainService,
        permissionManager: AccessibilityPermissionManager,
        notificationService: NotificationService,
        correctionCoordinator: CorrectionCoordinator
    ) {
        self.settingsStore = settingsStore
        self.keychainService = keychainService
        self.permissionManager = permissionManager
        self.notificationService = notificationService
        self.correctionCoordinator = correctionCoordinator
    }
}
