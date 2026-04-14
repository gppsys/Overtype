import Foundation

struct RiskAssessmentService {
    let suspiciousShrinkRatio: Double = 0.3
    let suspiciousGrowthRatio: Double = 4
    private let languageHeuristics = LanguageHeuristics()

    func assess(originalText: String, correctedText: String, action: TextTransformationAction) -> String? {
        let originalCore = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let correctedCore = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if correctedCore.isEmpty {
            return "La respuesta llegó vacía."
        }

        switch action {
        case .correct:
            if languageHeuristics.correctionLooksTranslated(original: originalCore, corrected: correctedCore) {
                return "La respuesta parece haber cambiado de idioma en vez de solo corregir el texto."
            }
        case .translateToEnglish:
            if languageHeuristics.translationDoesNotLookEnglish(original: originalCore, translated: correctedCore) {
                return "La respuesta no parece una traducción clara al inglés."
            }
        }

        if originalCore.count < 120 {
            return nil
        }

        if action == .correct {
            let lengthRatio = Double(correctedCore.count) / Double(max(1, originalCore.count))
            if originalCore.count >= 900 && lengthRatio < suspiciousShrinkRatio {
                return "La respuesta parece truncada respecto al texto original."
            }

            if lengthRatio > suspiciousGrowthRatio {
                return "La respuesta creció demasiado y puede contener texto extra."
            }
        }

        let originalParagraphs = countMeaningfulParagraphs(in: originalCore)
        let correctedParagraphs = countMeaningfulParagraphs(in: correctedCore)
        if originalParagraphs >= 3 && correctedParagraphs == 1 {
            return "Se perdieron saltos de párrafo importantes."
        }

        let originalListItems = countListItems(in: originalCore)
        let correctedListItems = countListItems(in: correctedCore)
        if originalListItems >= 3 && correctedListItems == 0 {
            return "Se perdió la estructura de lista del texto original."
        }

        return nil
    }

    private func countMeaningfulParagraphs(in text: String) -> Int {
        let parts = text.components(separatedBy: "\n\n")
        return parts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private func countListItems(in text: String) -> Int {
        let pattern = #"(?m)^\s*(?:[-*•]|\d+[.)])\s+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.numberOfMatches(in: text, range: range)
    }
}
