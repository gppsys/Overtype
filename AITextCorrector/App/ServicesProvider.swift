import AppKit
import Foundation

@MainActor
final class ServicesProvider: NSObject {
    let coordinator: CorrectionCoordinator

    init(coordinator: CorrectionCoordinator) {
        self.coordinator = coordinator
    }

    @objc func correctSelectedTextService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        runService(pasteboard: pasteboard, toneOverride: nil, error: error)
    }

    @objc func correctFriendlyTextService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        runService(pasteboard: pasteboard, toneOverride: "Friendly", error: error)
    }

    @objc func correctFormalTextService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        runService(pasteboard: pasteboard, toneOverride: "Formal", error: error)
    }

    @objc func correctBusinessTextService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        runService(pasteboard: pasteboard, toneOverride: "Business", error: error)
    }

    @objc func correctTechnicalTextService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        runService(pasteboard: pasteboard, toneOverride: "Technical", error: error)
    }

    @objc func correctConciseTextService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        runService(pasteboard: pasteboard, toneOverride: "Concise", error: error)
    }

    private func runService(pasteboard: NSPasteboard, toneOverride: String?, error errorPointer: AutoreleasingUnsafeMutablePointer<NSString>) {
        do {
            try coordinator.correctServicePasteboard(pasteboard, toneOverride: toneOverride)
        } catch {
            errorPointer.pointee = error.localizedDescription as NSString
        }
    }
}
