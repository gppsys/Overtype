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
    var customTones: [ToneOption]

    init(defaultTone: String, temperature: Double, maxInputChars: Int, maxOutputTokens: Int,
         model: String, globalShortcut: Shortcut, translateToEnglishShortcut: Shortcut,
         showNotifications: Bool, replaceAutomaticallyWhenPossible: Bool,
         enableTechnicalLogs: Bool, restoreClipboardAfterDirectReplacement: Bool,
         customTones: [ToneOption]) {
        self.defaultTone = defaultTone
        self.temperature = temperature
        self.maxInputChars = maxInputChars
        self.maxOutputTokens = maxOutputTokens
        self.model = model
        self.globalShortcut = globalShortcut
        self.translateToEnglishShortcut = translateToEnglishShortcut
        self.showNotifications = showNotifications
        self.replaceAutomaticallyWhenPossible = replaceAutomaticallyWhenPossible
        self.enableTechnicalLogs = enableTechnicalLogs
        self.restoreClipboardAfterDirectReplacement = restoreClipboardAfterDirectReplacement
        self.customTones = customTones
    }

    // Custom decoder so that settings saved before new fields were added
    // can still be loaded — missing keys fall back to the default values.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        defaultTone                       = (try? c.decode(String.self,    forKey: .defaultTone))                       ?? d.defaultTone
        temperature                       = (try? c.decode(Double.self,    forKey: .temperature))                       ?? d.temperature
        maxInputChars                     = (try? c.decode(Int.self,       forKey: .maxInputChars))                     ?? d.maxInputChars
        maxOutputTokens                   = (try? c.decode(Int.self,       forKey: .maxOutputTokens))                   ?? d.maxOutputTokens
        model                             = (try? c.decode(String.self,    forKey: .model))                             ?? d.model
        globalShortcut                    = (try? c.decode(Shortcut.self,  forKey: .globalShortcut))                    ?? d.globalShortcut
        translateToEnglishShortcut        = (try? c.decode(Shortcut.self,  forKey: .translateToEnglishShortcut))        ?? d.translateToEnglishShortcut
        showNotifications                 = (try? c.decode(Bool.self,      forKey: .showNotifications))                 ?? d.showNotifications
        replaceAutomaticallyWhenPossible  = (try? c.decode(Bool.self,      forKey: .replaceAutomaticallyWhenPossible))  ?? d.replaceAutomaticallyWhenPossible
        enableTechnicalLogs               = (try? c.decode(Bool.self,      forKey: .enableTechnicalLogs))               ?? d.enableTechnicalLogs
        restoreClipboardAfterDirectReplacement = (try? c.decode(Bool.self, forKey: .restoreClipboardAfterDirectReplacement)) ?? d.restoreClipboardAfterDirectReplacement
        customTones                       = (try? c.decode([ToneOption].self, forKey: .customTones))                    ?? d.customTones
    }

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
        restoreClipboardAfterDirectReplacement: true,
        customTones: []
    )
}

// MARK: - ToneOption helpers

extension ToneOption {
    /// Prefix that marks a custom tone whose `id` carries full prompt instructions.
    static let customPrefix = "⚙:"

    /// Create a user-defined tone. The instructions are embedded in the id so they
    /// flow through the existing `tone: String` pipeline without extra plumbing.
    static func custom(title: String, instructions: String) -> ToneOption {
        ToneOption(id: "\(customPrefix)\(instructions)", title: title)
    }

    var isCustom: Bool { id.hasPrefix(Self.customPrefix) }

    /// The instruction text sent to the model.
    /// For built-in presets this is the short name; for custom tones it's the full description.
    var promptInstructions: String {
        isCustom ? String(id.dropFirst(Self.customPrefix.count)) : id
    }

    /// Presets + user-defined custom tones.
    static func allTones(from settings: AppSettings) -> [ToneOption] {
        ToneOption.presets + settings.customTones
    }
}
