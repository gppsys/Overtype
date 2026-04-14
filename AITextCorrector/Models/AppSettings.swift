import AppKit
import Carbon.HIToolbox
import Foundation

struct Shortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiersRawValue: UInt

    static let `default` = Shortcut(
        keyCode: UInt32(kVK_ANSI_C),
        modifiersRawValue: NSEvent.ModifierFlags([.control, .option, .command]).rawValue
    )

    static let translateDefault = Shortcut(
        keyCode: UInt32(kVK_ANSI_E),
        modifiersRawValue: NSEvent.ModifierFlags([.control, .option, .command]).rawValue
    )

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifierFlags.contains(.command) { result |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { result |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { result |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

struct ToneOption: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String

    static let presets: [ToneOption] = [
        .init(id: "Friendly", title: "Friendly"),
        .init(id: "Friendly but format the main ideas in bullets", title: "Friendly with bullets"),
        .init(id: "Token-efficient for AI prompts", title: "Token-efficient"),
        .init(id: "Technical", title: "Technical"),
        .init(id: "Business", title: "Business"),
        .init(id: "Casual", title: "Casual"),
        .init(id: "Formal", title: "Formal"),
        .init(id: "Creative", title: "Creative"),
        .init(id: "Academic", title: "Academic"),
        .init(id: "Persuasive", title: "Persuasive"),
        .init(id: "Concise", title: "Concise"),
        .init(id: "Descriptive", title: "Descriptive"),
        .init(id: "Humorous", title: "Humorous"),
        .init(id: "Empathetic", title: "Empathetic"),
        .init(id: "Inspirational", title: "Inspirational"),
        .init(id: "Neutral", title: "Neutral")
    ]
}

struct AppSettings: Codable, Equatable, Sendable {
    var defaultTone: String
    var temperature: Double
    var maxInputChars: Int
    var maxOutputTokens: Int
    var model: String
    var globalShortcut: Shortcut
    var translateToEnglishShortcut: Shortcut
    var showNotifications: Bool
    var replaceAutomaticallyWhenPossible: Bool
    var enableTechnicalLogs: Bool
    var restoreClipboardAfterDirectReplacement: Bool

    static let `default` = AppSettings(
        defaultTone: ToneOption.presets.first?.id ?? "Friendly",
        temperature: 0.3,
        maxInputChars: 24_000,
        maxOutputTokens: 2_000,
        model: "gpt-4o-mini",
        globalShortcut: .default,
        translateToEnglishShortcut: .translateDefault,
        showNotifications: true,
        replaceAutomaticallyWhenPossible: true,
        enableTechnicalLogs: false,
        restoreClipboardAfterDirectReplacement: true
    )
}
