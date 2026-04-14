import Foundation

struct LanguageHeuristics {
    enum LanguageKind {
        case english
        case spanish
        case unknown
    }

    func dominantLanguage(in text: String) -> LanguageKind {
        let analysis = analyze(text)
        return analysis.language
    }

    func correctionLooksTranslated(original: String, corrected: String) -> Bool {
        let originalAnalysis = analyze(original)
        let correctedAnalysis = analyze(corrected)

        guard originalAnalysis.confidence >= 0.45, correctedAnalysis.confidence >= 0.45 else {
            return false
        }

        switch (originalAnalysis.language, correctedAnalysis.language) {
        case (.spanish, .english), (.english, .spanish):
            return tokenOverlapRatio(between: original, and: corrected) < 0.35
        default:
            return false
        }
    }

    func translationDoesNotLookEnglish(original: String, translated: String) -> Bool {
        let originalAnalysis = analyze(original)
        let translatedAnalysis = analyze(translated)

        if translatedAnalysis.language == .english && translatedAnalysis.confidence >= 0.35 {
            return false
        }

        if originalAnalysis.language == .english {
            return false
        }

        if originalAnalysis.language == translatedAnalysis.language,
           originalAnalysis.language != .unknown,
           translatedAnalysis.confidence >= 0.45 {
            return true
        }

        return tokenOverlapRatio(between: original, and: translated) > 0.8
    }

    private func analyze(_ text: String) -> LanguageAnalysis {
        let lowercase = text.lowercased()
        let tokens = wordTokens(in: lowercase)

        let englishTokenHits = Double(tokens.filter { Self.englishMarkers.contains($0) }.count)
        let spanishTokenHits = Double(tokens.filter { Self.spanishMarkers.contains($0) }.count)
        let englishPhraseHits = containsAnyPhrase(in: lowercase, phrases: Self.englishPhrases) ? 2.0 : 0.0
        let spanishPhraseHits = containsAnyPhrase(in: lowercase, phrases: Self.spanishPhrases) ? 2.0 : 0.0
        let spanishCharacterHits = Double(lowercase.filter { "áéíóúñ¿¡".contains($0) }.count) * 1.5

        let englishScore = englishTokenHits + englishPhraseHits
        let spanishScore = spanishTokenHits + spanishPhraseHits + spanishCharacterHits
        let margin = abs(englishScore - spanishScore)
        let maxScore = max(englishScore, spanishScore)
        let totalScore = englishScore + spanishScore

        guard maxScore >= 2.0, margin >= 1.5 else {
            return LanguageAnalysis(language: .unknown, confidence: 0)
        }

        let confidence = totalScore == 0 ? 0 : maxScore / totalScore
        if englishScore > spanishScore {
            return LanguageAnalysis(language: .english, confidence: confidence)
        }

        return LanguageAnalysis(language: .spanish, confidence: confidence)
    }

    private func wordTokens(in text: String) -> [String] {
        let pattern = #"[[:alpha:]][[:alpha:]']*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: text) else { return nil }
            return String(text[tokenRange])
        }
    }

    private func containsAnyPhrase(in text: String, phrases: Set<String>) -> Bool {
        phrases.contains { text.contains($0) }
    }

    private func tokenOverlapRatio(between lhs: String, and rhs: String) -> Double {
        let lhsTokens = Set(wordTokens(in: lhs.lowercased()).filter { $0.count >= 3 })
        let rhsTokens = Set(wordTokens(in: rhs.lowercased()).filter { $0.count >= 3 })

        guard lhsTokens.count >= 4, rhsTokens.count >= 4 else {
            return 0
        }

        let overlap = lhsTokens.intersection(rhsTokens)
        return Double(overlap.count) / Double(min(lhsTokens.count, rhsTokens.count))
    }

    private struct LanguageAnalysis {
        let language: LanguageKind
        let confidence: Double
    }

    private static let englishMarkers: Set<String> = [
        "the", "and", "are", "for", "with", "that", "this", "from", "have", "will",
        "your", "about", "into", "only", "just", "what", "when", "where", "should",
        "would", "could", "please", "thanks", "there", "their", "them", "they"
    ]

    private static let spanishMarkers: Set<String> = [
        "que", "para", "con", "como", "pero", "porque", "esta", "este", "estos", "estas",
        "hola", "texto", "seleccionado", "corregir", "traduccion", "ingles", "idioma",
        "solo", "tambien", "gracias", "favor", "cuando", "donde", "puede", "debe"
    ]

    private static let englishPhrases: Set<String> = [
        "in the", "to the", "for the", "on the", "with the", "do not", "return only"
    ]

    private static let spanishPhrases: Set<String> = [
        "de la", "de el", "para el", "para la", "no se", "solo el", "por favor"
    ]
}
