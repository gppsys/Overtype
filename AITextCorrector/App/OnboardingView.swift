import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Text Corrector para macOS")
                .font(.title2.weight(.semibold))

            Text("Selecciona texto en cualquier app, usa el atajo global o un Service y la app intentara corregirlo con OpenAI. Cuando el reemplazo directo no sea posible, copiara el resultado al portapapeles.")

            GroupBox("Checklist inicial") {
                VStack(alignment: .leading, spacing: 10) {
                    permissionRow("1. Guarda tu API key en Settings.", done: hasStoredAPIKey)
                    permissionRow("2. Concede Accessibility para leer o reemplazar texto.", done: appState.permissionManager.accessibilityTrusted)
                    permissionRow("3. Permite notificaciones si quieres feedback del flujo.", done: appState.permissionManager.notificationsAuthorized)
                    permissionRow("4. Prueba el atajo global en Notes o TextEdit antes de ir a apps mas restrictivas.", done: false)
                }
            }

            GroupBox("Limitaciones reales") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("El atajo global y Accessibility permiten cubrir muchos campos de texto, pero no todos.")
                    Text("Algunas apps no exponen seleccion o no permiten escritura mediante Accessibility.")
                    Text("Los Services aparecen solo en apps que publican texto seleccionado al sistema.")
                    Text("Cuando macOS o la app bloquean el reemplazo, el fallback seguro es copiar el resultado al portapapeles.")
                }
            }

            HStack {
                Button("Abrir Settings") {
                    NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
                }
                Button("Pedir Accessibility") {
                    appState.permissionManager.requestAccessibilityTrust()
                }
                Button("Refrescar permisos") {
                    Task { await appState.permissionManager.refresh() }
                }
            }
        }
        .padding(24)
        .frame(width: 620)
        .task { await appState.permissionManager.refresh() }
    }

    private var hasStoredAPIKey: Bool {
        ((try? appState.keychainService.loadAPIKey()) ?? "").isEmpty == false
    }

    private func permissionRow(_ title: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
            Text(title)
        }
    }
}
