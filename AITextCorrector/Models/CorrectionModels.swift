import Foundation

enum TextTransformationAction: String, Codable, Sendable {
    case correct
    case translateToEnglish

    var title: String {
        switch self {
        case .correct:
            return "Corregir"
        case .translateToEnglish:
            return "Traducir a inglés"
        }
    }
}

struct CorrectionRequest: Sendable {
    let text: String
    let tone: String
    let action: TextTransformationAction
    let settings: AppSettings
}

struct CorrectionResult: Sendable {
    let correctedText: String
    let manualReviewReason: String?
}

struct CapturedSelection {
    let text: String
    let accessibilityContext: AccessibilitySelectionContext?
}

struct CaptureDiagnosticReport: Sendable {
    let appName: String?
    let usedAccessibility: Bool
    let accessibilityDetail: String
    let usedClipboardFallback: Bool
    let clipboardDetail: String
    let finalStatus: String
}

struct AccessibilityEnvironmentDiagnostic: Sendable {
    let bundleIdentifier: String
    let bundlePath: String
    let executablePath: String
    let isTrusted: Bool
    let launchedFromXcode: Bool
    let helpText: String
}
