import AppKit
import Foundation

@MainActor
final class CorrectionCoordinator {
    private let settingsStore: SettingsStore
    private let keychainService: KeychainService
    private let captureService: TextSelectionCaptureService
    private let replacementService: TextReplacementService
    private let correctionService: CorrectionService
    private let notificationService: NotificationService
    private weak var appState: AppState?

    init(
        settingsStore: SettingsStore,
        keychainService: KeychainService,
        captureService: TextSelectionCaptureService,
        replacementService: TextReplacementService,
        correctionService: CorrectionService,
        notificationService: NotificationService
    ) {
        self.settingsStore = settingsStore
        self.keychainService = keychainService
        self.captureService = captureService
        self.replacementService = replacementService
        self.correctionService = correctionService
        self.notificationService = notificationService
    }

    func attach(appState: AppState) {
        self.appState = appState
    }

    func correctSelection(toneOverride: String? = nil) {
        Task {
            await runSelectionCorrection(toneOverride: toneOverride, action: .correct)
        }
    }

    func translateSelectionToEnglish(toneOverride: String? = nil) {
        Task {
            await runSelectionCorrection(toneOverride: toneOverride, action: .translateToEnglish)
        }
    }

    func captureSelectionForPalette() async -> CapturedSelection? {
        do {
            let selection = try await captureService.captureSelectedText()
            appState?.lastCaptureDiagnostic = captureService.lastDiagnosticReport
            appState?.lastErrorMessage = nil
            return selection
        } catch {
            appState?.lastCaptureDiagnostic = captureService.lastDiagnosticReport
            appState?.lastErrorMessage = error.localizedDescription
            try? await notify(error.localizedDescription)
            return nil
        }
    }

    func correctCapturedSelection(_ selection: CapturedSelection, toneOverride: String? = nil) {
        Task {
            await runCorrection(for: selection, toneOverride: toneOverride, action: .correct)
        }
    }

    func translateCapturedSelectionToEnglish(_ selection: CapturedSelection, toneOverride: String? = nil) {
        Task {
            await runCorrection(for: selection, toneOverride: toneOverride, action: .translateToEnglish)
        }
    }

    func correctServicePasteboard(_ pasteboard: NSPasteboard, toneOverride: String? = nil) throws {
        let selection = try captureService.captureFromServicePasteboard(pasteboard)
        let result = try blockingCorrection(for: selection, toneOverride: toneOverride)
        pasteboard.clearContents()
        pasteboard.setString(result.correctedText, forType: .string)
    }

    func runTestCorrection(sampleText: String) {
        Task {
            do {
                let result = try await correctRawText(sampleText, toneOverride: nil)
                await notificationService.send(title: "AI Text Corrector", body: result.correctedText)
            } catch {
                await notificationService.send(title: "AI Text Corrector", body: error.localizedDescription)
            }
        }
    }

    private func blockingCorrection(for selection: CapturedSelection, toneOverride: String?) throws -> CorrectionResult {
        let execution = try makeExecutionContext(for: selection.text, toneOverride: toneOverride, action: .correct)
        let semaphore = DispatchSemaphore(value: 0)
        let box = BlockingResultBox()
        let correctionService = self.correctionService
        Task {
            do {
                let result = try await correctionService.correctText(
                    execution.request,
                    apiKey: execution.apiKey,
                    showNotifications: execution.showNotifications
                )
                box.result = .success(result)
            } catch {
                box.result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try box.result?.get() ?? { throw NSError(domain: "AITextCorrector.Service", code: -1, userInfo: [NSLocalizedDescriptionKey: "La corrección no devolvió resultado."]) }()
    }

    private func runSelectionCorrection(toneOverride: String?, action: TextTransformationAction) async {
        guard !settingsStore.settings.model.isEmpty else { return }
        do {
            let selection = try await captureService.captureSelectedText()
            appState?.lastCaptureDiagnostic = captureService.lastDiagnosticReport
            await runCorrection(for: selection, toneOverride: toneOverride, action: action)
        } catch {
            appState?.lastCaptureDiagnostic = captureService.lastDiagnosticReport
            appState?.lastErrorMessage = error.localizedDescription
            try? await notify(error.localizedDescription)
        }
    }

    private func runCorrection(for selection: CapturedSelection, toneOverride: String?, action: TextTransformationAction) async {
        guard !settingsStore.settings.model.isEmpty else { return }
        appState?.isProcessing = true
        appState?.statusMessage = action == .correct ? "Corrigiendo..." : "Traduciendo..."
        defer {
            appState?.isProcessing = false
            appState?.statusMessage = "Listo"
            appState?.processingProgress = nil
        }

        do {
            let result = try await transformRawText(selection.text, toneOverride: toneOverride, action: action)

            if let manualReviewReason = result.manualReviewReason {
                try replacementService.copyToClipboard(result.correctedText)
                let copiedMessage = action == .correct
                    ? "Texto corregido copiado al portapapeles. Revisión manual requerida: \(manualReviewReason)"
                    : "Traducción al inglés copiada al portapapeles. Revisión manual requerida: \(manualReviewReason)"
                try await notify(copiedMessage)
                return
            }

            let replacementStrategy = AppReplacementHeuristics.strategy(for: selection.appBundleIdentifier)

            if replacementStrategy == .accessibilityPreferred,
               settingsStore.settings.replaceAutomaticallyWhenPossible,
               let context = selection.accessibilityContext {
                do {
                    try replacementService.replace(result.correctedText, using: context)
                    let message = action == .correct
                        ? "Texto corregido y reemplazado en la app activa."
                        : "Texto traducido al inglés y reemplazado en la app activa."
                    try await notify(message)
                    return
                } catch {
                    try await copyAndAttemptPasteFallback(result.correctedText, action: action)
                    return
                }
            }

            try await copyAndAttemptPasteFallback(result.correctedText, action: action)
        } catch {
            appState?.lastErrorMessage = error.localizedDescription
            try? await notify(error.localizedDescription)
        }
    }

    private func correctRawText(_ text: String, toneOverride: String?) async throws -> CorrectionResult {
        try await transformRawText(text, toneOverride: toneOverride, action: .correct)
    }

    private func transformRawText(_ text: String, toneOverride: String?, action: TextTransformationAction) async throws -> CorrectionResult {
        let execution = try makeExecutionContext(for: text, toneOverride: toneOverride, action: action)
        let progress: @Sendable (Int, Int) -> Void = { [weak appState] current, total in
            guard total > 1 else { return }
            Task { @MainActor [weak appState] in
                appState?.processingProgress = (current: current, total: total)
            }
        }
        return try await correctionService.correctText(
            execution.request,
            apiKey: execution.apiKey,
            showNotifications: execution.showNotifications,
            onProgress: progress
        )
    }

    private func makeExecutionContext(for text: String, toneOverride: String?, action: TextTransformationAction) throws -> CorrectionExecutionContext {
        let settings = settingsStore.settings
        guard text.count <= settings.maxInputChars else {
            throw NSError(domain: "AITextCorrector.Input", code: 1, userInfo: [NSLocalizedDescriptionKey: "El texto seleccionado tiene \(text.count) caracteres y el límite actual es \(settings.maxInputChars)."])
        }

        guard let apiKey = try keychainService.loadAPIKey(), !apiKey.isEmpty else {
            throw NSError(domain: "AITextCorrector.Keychain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Configura primero tu API key de OpenAI en Settings."])
        }

        let request = CorrectionRequest(
            text: text,
            tone: toneOverride ?? settings.defaultTone,
            action: action,
            settings: settings
        )

        return CorrectionExecutionContext(
            request: request,
            apiKey: apiKey,
            showNotifications: settings.showNotifications
        )
    }

    private func notify(_ body: String) async throws {
        if settingsStore.settings.showNotifications {
            await notificationService.send(title: "AI Text Corrector", body: body)
        }
    }

    private func copyAndAttemptPasteFallback(_ text: String, action: TextTransformationAction) async throws {
        // Corrected text lands in the clipboard first so the user can always paste manually
        // even if the automatic Cmd+V below doesn't land.
        try replacementService.copyToClipboard(text)

        guard settingsStore.settings.replaceAutomaticallyWhenPossible else {
            let copiedMessage = action == .correct
                ? "Texto corregido copiado al portapapeles."
                : "Traducción al inglés copiada al portapapeles."
            try await notify(copiedMessage)
            return
        }

        let pastedMessage = action == .correct
            ? "Texto corregido pegado automáticamente."
            : "Traducción al inglés pegada automáticamente."

        do {
            try await replacementService.pasteFromClipboardIntoFocusedApp()
            try await notify(pastedMessage)
        } catch {
            // One retry after a short delay in case the app needed a moment to settle.
            do {
                try await Task.sleep(for: .milliseconds(120))
                try await replacementService.pasteFromClipboardIntoFocusedApp()
                try await notify(pastedMessage)
            } catch {
                // Paste failed — corrected text is still in the clipboard for manual paste.
                let copiedMessage = action == .correct
                    ? "Texto corregido copiado al portapapeles (pegado manual necesario)."
                    : "Traducción al inglés copiada al portapapeles (pegado manual necesario)."
                try await notify(copiedMessage)
            }
        }
    }
}

private struct CorrectionExecutionContext: Sendable {
    let request: CorrectionRequest
    let apiKey: String
    let showNotifications: Bool
}

private final class BlockingResultBox: @unchecked Sendable {
    var result: Result<CorrectionResult, Error>?
}
