import Foundation

enum OutputSanitizer {
    private static let replacements: [Character: String] = [
        "\u{2014}": "-",
        "\u{2013}": "-",
        "\u{2012}": "-",
        "\u{2212}": "-",
        "\u{2018}": "'",
        "\u{2019}": "'",
        "\u{201A}": "'",
        "\u{2032}": "'",
        "\u{201C}": "\"",
        "\u{201D}": "\"",
        "\u{201E}": "\"",
        "\u{00AB}": "\"",
        "\u{00BB}": "\"",
        "\u{2026}": "...",
        "\u{00A0}": " ",
        "\u{2007}": " ",
        "\u{202F}": " ",
        "\u{200B}": "",
        "\u{200C}": "",
        "\u{200D}": "",
        "\u{2060}": "",
        "\u{FEFF}": ""
    ]

    static func sanitize(_ text: String) -> String {
        var output = ""
        output.reserveCapacity(text.count)
        for character in text {
            output += replacements[character] ?? String(character)
        }
        return output.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func stripCodeFences(_ text: String) -> String {
        let pattern = #"^```(?:[\w-]+)?\s*([\s\S]*?)\s*```$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return text
        }
        return String(text[captureRange])
    }
}
