import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    @State private var apiKey = ""
    @State private var hasStoredAPIKey = false
    @State private var revealAPIKey = false
    @State private var saveMessage: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                openAICard
                correctionCard
                integrationCard
                permissionsCard
                environmentCard
                diagnosticsCard
                testCard
            }
            .padding(24)
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 680, idealHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await refreshViewState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshUIState)) { _ in
            Task { await refreshViewState() }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuración")
                .font(.title2.weight(.semibold))
            Text("Ajusta OpenAI, el tono, los límites y la integración con macOS. La API key se guarda en Keychain.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var openAICard: some View {
        settingsCard("OpenAI") {
            VStack(alignment: .leading, spacing: 14) {
                Text("API key")
                    .font(.headline)

                HStack(spacing: 10) {
                    Image(systemName: hasStoredAPIKey ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(hasStoredAPIKey ? .green : .orange)
                    Text(hasStoredAPIKey ? "API key detectada en Keychain" : "No hay API key guardada")
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if revealAPIKey {
                            TextField("sk-...", text: $apiKey, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...3)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Toggle("Mostrar", isOn: $revealAPIKey)
                        .toggleStyle(.checkbox)
                        .frame(width: 90, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button(isSaving ? "Guardando..." : "Guardar API key") {
                        saveAPIKey()
                    }
                    .disabled(isSaving || trimmedAPIKey.isEmpty)

                    Button("Pegar desde portapapeles") {
                        apiKey = NSPasteboard.general.string(forType: .string) ?? apiKey
                        saveMessage = nil
                    }

                    if !apiKey.isEmpty {
                        Button("Limpiar") {
                            apiKey = ""
                            saveMessage = nil
                        }
                    }
                }

                if let saveMessage {
                    Text(saveMessage)
                        .foregroundStyle(saveMessage.contains("guardada") ? .green : .red)
                        .font(.subheadline)
                }

                LabeledContent("Modelo") {
                    TextField("gpt-4o-mini", text: modelBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }
        }
    }

    private var correctionCard: some View {
        settingsCard("Corrección") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tono predeterminado actual")
                            .font(.subheadline.weight(.semibold))
                        Text(selectedToneOption.title)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Tono predeterminado") {
                    Picker("Tono predeterminado", selection: toneBinding) {
                        ForEach(ToneOption.presets) { tone in
                            Text(tone.title).tag(tone.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 280)
                }

                Text("Este será el tono usado por defecto cuando corrijas con el shortcut global o con la opción general de la menubar.")
                    .foregroundStyle(.secondary)

                LabeledContent("Temperature") {
                    HStack(spacing: 10) {
                        Slider(value: temperatureBinding, in: 0...1)
                            .frame(width: 220)
                        Text(appState.settingsStore.settings.temperature.formatted(.number.precision(.fractionLength(1))))
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                }

                LabeledContent("Max input chars") {
                    Stepper(value: maxInputBinding, in: 1_000...120_000, step: 500) {
                        Text("\(appState.settingsStore.settings.maxInputChars)")
                            .monospacedDigit()
                    }
                    .frame(width: 220, alignment: .leading)
                }

                LabeledContent("Max output tokens") {
                    Stepper(value: maxOutputBinding, in: 300...8_000, step: 100) {
                        Text("\(appState.settingsStore.settings.maxOutputTokens)")
                            .monospacedDigit()
                    }
                    .frame(width: 220, alignment: .leading)
                }
            }
        }
    }

    private var integrationCard: some View {
        settingsCard("Integración") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Shortcut corregir") {
                    ShortcutRecorderView(shortcut: shortcutBinding, defaultShortcut: .default)
                }
                if let shortcutRegistrationMessage = appState.shortcutRegistrationMessage {
                    Text(shortcutRegistrationMessage)
                        .foregroundStyle(shortcutRegistrationMessage.contains("conflicto") || shortcutRegistrationMessage.contains("VoiceOver") ? .orange : .secondary)
                        .font(.subheadline)
                }
                LabeledContent("Shortcut traducir a inglés") {
                    ShortcutRecorderView(shortcut: translateShortcutBinding, defaultShortcut: .translateDefault)
                }
                if let translateShortcutRegistrationMessage = appState.translateShortcutRegistrationMessage {
                    Text(translateShortcutRegistrationMessage)
                        .foregroundStyle(translateShortcutRegistrationMessage.contains("conflicto") || translateShortcutRegistrationMessage.contains("VoiceOver") ? .orange : .secondary)
                        .font(.subheadline)
                }
                Toggle("Mostrar notificaciones", isOn: showNotificationsBinding)
                Toggle("Reemplazar automáticamente cuando sea posible", isOn: replaceAutomaticallyBinding)
                Toggle("Restaurar portapapeles tras reemplazo directo", isOn: restoreClipboardBinding)
                Toggle("Logs técnicos opcionales", isOn: technicalLogsBinding)
            }
        }
    }

    private var permissionsCard: some View {
        settingsCard("Permisos") {
            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    isGranted: appState.permissionManager.accessibilityTrusted,
                    grantedText: "Permitido",
                    missingText: "Pendiente"
                )
                permissionRow(
                    title: "Notificaciones",
                    isGranted: appState.permissionManager.notificationsAuthorized,
                    grantedText: "Permitidas",
                    missingText: "Pendientes"
                )

                HStack(spacing: 12) {
                    Button("Pedir Accessibility") {
                        appState.permissionManager.requestAccessibilityTrust()
                        Task { await refreshViewState() }
                    }
                    Button("Abrir ajustes de Accessibility") {
                        appState.permissionManager.openAccessibilitySettings()
                    }
                    Button("Abrir ajustes de notificaciones") {
                        appState.permissionManager.openNotificationSettings()
                    }
                }
            }
        }
    }

    private var testCard: some View {
        settingsCard("Prueba") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Usa esta acción para comprobar rápidamente que OpenAI responde con tu configuración actual.")
                    .foregroundStyle(.secondary)
                Button("Probar corrección") {
                    appState.correctionCoordinator.runTestCorrection(sampleText: "hola, esto es un texto de prueba sin puntuacion correcta y con errores gramaticales")
                }
                if let lastError = appState.lastErrorMessage {
                    Text(lastError)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
        }
    }

    private var diagnosticsCard: some View {
        settingsCard("Diagnóstico de captura") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Este panel muestra el último intento de capturar texto para ayudarte a identificar si falló Accessibility o el fallback por portapapeles.")
                    .foregroundStyle(.secondary)

                if let diagnostic = appState.lastCaptureDiagnostic {
                    diagnosticRow("App activa", diagnostic.appName ?? "Desconocida")
                    diagnosticRow("Resultado final", diagnostic.finalStatus)
                    diagnosticRow("Accessibility", diagnostic.usedAccessibility ? "Usado" : "No usado")
                    diagnosticRow("Detalle AX", diagnostic.accessibilityDetail)
                    diagnosticRow("Fallback portapapeles", diagnostic.usedClipboardFallback ? "Intentado" : "No intentado")
                    diagnosticRow("Detalle portapapeles", diagnostic.clipboardDetail)
                } else {
                    Text("Todavía no hay intentos registrados. Ejecuta una corrección con el atajo global para ver el diagnóstico aquí.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var environmentCard: some View {
        settingsCard("Diagnóstico de permisos") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Este bloque ayuda a detectar si macOS dio permiso a otra copia del .app o si hace falta relanzar la app después de aprobar Accessibility.")
                    .foregroundStyle(.secondary)

                if let diagnostic = appState.accessibilityEnvironmentDiagnostic {
                    diagnosticRow("Accessibility real", diagnostic.isTrusted ? "Concedido" : "No concedido")
                    diagnosticRow("Lanzada desde Xcode", diagnostic.launchedFromXcode ? "Sí" : "No")
                    diagnosticRow("Bundle ID", diagnostic.bundleIdentifier)
                    diagnosticRow("Ruta del .app", diagnostic.bundlePath)
                    diagnosticRow("Ruta del ejecutable", diagnostic.executablePath)
                    diagnosticRow("Lectura", diagnostic.helpText)

                    HStack(spacing: 12) {
                        Button("Copiar diagnóstico") {
                            let text = [
                                "Accessibility real: \(diagnostic.isTrusted ? "Concedido" : "No concedido")",
                                "Lanzada desde Xcode: \(diagnostic.launchedFromXcode ? "Sí" : "No")",
                                "Bundle ID: \(diagnostic.bundleIdentifier)",
                                "Ruta del .app: \(diagnostic.bundlePath)",
                                "Ruta del ejecutable: \(diagnostic.executablePath)",
                                "Lectura: \(diagnostic.helpText)"
                            ].joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }
                        Button("Refrescar diagnóstico") {
                            Task { await refreshViewState() }
                        }
                    }
                } else {
                    Text("Aún no hay diagnóstico cargado.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func permissionRow(title: String, isGranted: Bool, grantedText: String, missingText: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isGranted ? .green : .orange)
            Text(title)
                .frame(width: 120, alignment: .leading)
            Text(isGranted ? grantedText : missingText)
                .foregroundStyle(.secondary)
        }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedToneOption: ToneOption {
        ToneOption.presets.first(where: { $0.id == appState.settingsStore.settings.defaultTone })
            ?? ToneOption(id: appState.settingsStore.settings.defaultTone, title: appState.settingsStore.settings.defaultTone)
    }

    private var toneBinding: Binding<String> {
        Binding(
            get: { appState.settingsStore.settings.defaultTone },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.defaultTone = value.isEmpty ? AppSettings.default.defaultTone : value
                }
            }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { appState.settingsStore.settings.temperature },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.temperature = value
                }
            }
        )
    }

    private var maxInputBinding: Binding<Int> {
        Binding(
            get: { appState.settingsStore.settings.maxInputChars },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.maxInputChars = value
                }
            }
        )
    }

    private var maxOutputBinding: Binding<Int> {
        Binding(
            get: { appState.settingsStore.settings.maxOutputTokens },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.maxOutputTokens = value
                }
            }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { appState.settingsStore.settings.model },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.model = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }

    private var shortcutBinding: Binding<Shortcut> {
        Binding(
            get: { appState.settingsStore.settings.globalShortcut },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.globalShortcut = value
                }
            }
        )
    }

    private var showNotificationsBinding: Binding<Bool> {
        Binding(
            get: { appState.settingsStore.settings.showNotifications },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.showNotifications = value
                }
            }
        )
    }

    private var translateShortcutBinding: Binding<Shortcut> {
        Binding(
            get: { appState.settingsStore.settings.translateToEnglishShortcut },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.translateToEnglishShortcut = value
                }
            }
        )
    }

    private var replaceAutomaticallyBinding: Binding<Bool> {
        Binding(
            get: { appState.settingsStore.settings.replaceAutomaticallyWhenPossible },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.replaceAutomaticallyWhenPossible = value
                }
            }
        )
    }

    private var restoreClipboardBinding: Binding<Bool> {
        Binding(
            get: { appState.settingsStore.settings.restoreClipboardAfterDirectReplacement },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.restoreClipboardAfterDirectReplacement = value
                }
            }
        )
    }

    private var technicalLogsBinding: Binding<Bool> {
        Binding(
            get: { appState.settingsStore.settings.enableTechnicalLogs },
            set: { value in
                appState.settingsStore.update { settings in
                    settings.enableTechnicalLogs = value
                }
            }
        )
    }

    private func saveAPIKey() {
        let value = trimmedAPIKey
        guard !value.isEmpty else {
            saveMessage = "Pega una API key antes de guardar."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try appState.keychainService.saveAPIKey(value)
            apiKey = value
            hasStoredAPIKey = true
            saveMessage = "API key guardada correctamente en Keychain."
        } catch {
            saveMessage = "No se pudo guardar la API key: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func refreshViewState() async {
        let storedKey = (try? appState.keychainService.loadAPIKey()) ?? ""
        hasStoredAPIKey = !storedKey.isEmpty
        if !storedKey.isEmpty && apiKey.isEmpty {
            apiKey = storedKey
        }
        await appState.permissionManager.refresh()
        appState.accessibilityEnvironmentDiagnostic = appState.permissionManager.environmentDiagnostic
    }
}
