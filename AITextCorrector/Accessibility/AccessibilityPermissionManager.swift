import ApplicationServices
import AppKit
import Foundation
import UserNotifications

@MainActor
final class AccessibilityPermissionManager: ObservableObject {
    @Published private(set) var accessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var notificationsAuthorized = false
    @Published private(set) var environmentDiagnostic: AccessibilityEnvironmentDiagnostic?

    func refresh() async {
        accessibilityTrusted = AXIsProcessTrusted()
        environmentDiagnostic = buildEnvironmentDiagnostic(isTrusted: accessibilityTrusted)
        notificationsAuthorized = await notificationAuthorizationStatus()
    }

    func requestAccessibilityTrust() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        accessibilityTrusted = AXIsProcessTrusted()
        environmentDiagnostic = buildEnvironmentDiagnostic(isTrusted: accessibilityTrusted)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    private func notificationAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private func buildEnvironmentDiagnostic(isTrusted: Bool) -> AccessibilityEnvironmentDiagnostic {
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        let bundlePath = bundle.bundleURL.path
        let executablePath = bundle.executableURL?.path ?? ProcessInfo.processInfo.arguments.first ?? "unknown"
        let environment = ProcessInfo.processInfo.environment
        let launchedFromXcode = environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
            || environment["IDE_DISABLED_OS_ACTIVITY_DT_MODE"] != nil

        let helpText: String
        if isTrusted {
            helpText = "Accessibility responde como concedido para este binario."
        } else if launchedFromXcode {
            helpText = "La app parece ejecutarse desde Xcode. En macOS, Accessibility puede quedar concedido a otra copia del .app o requerir relanzar la app después de otorgar permiso."
        } else {
            helpText = "Accessibility sigue sin concederse para este binario. Verifica que la ruta del .app coincida con la entrada autorizada en System Settings y relanza la app."
        }

        return AccessibilityEnvironmentDiagnostic(
            bundleIdentifier: bundleIdentifier,
            bundlePath: bundlePath,
            executablePath: executablePath,
            isTrusted: isTrusted,
            launchedFromXcode: launchedFromXcode,
            helpText: helpText
        )
    }
}
