import Foundation

struct CorrectionPrompt {
    let instructions: String
    let text: String
}

struct PromptBuilder {
    func buildPrompt(text: String, tone: String, action: TextTransformationAction, chunkIndex: Int, totalChunks: Int, isRetry: Bool) -> CorrectionPrompt {
        let chunkContext = chunkContext(for: action, chunkIndex: chunkIndex, totalChunks: totalChunks)
        let retryContext = retryInstruction(for: action, isRetry: isRetry)
        let toneInstruction = toneInstruction(for: tone, action: action)
        let languageInstruction = languageInstruction(for: text, action: action)

        let lines = [
            operationInstruction(for: action),
            chunkContext,
            retryContext,
            toneInstruction,
            languageInstruction,
            transformationGuardrail(for: action),
            "Do not summarize, censor, explain, add headings, or wrap the answer in code fences.",
            "Preserve the original meaning, paragraph breaks, lists, and line structure.",
            outputInstruction(for: action)
        ].compactMap { $0 }

        return CorrectionPrompt(instructions: lines.joined(separator: "\n"), text: text)
    }

    private func operationInstruction(for action: TextTransformationAction) -> String {
        switch action {
        case .correct:
            return "Task mode: CORRECTION ONLY. You must correct the text in place. Translation is forbidden."
        case .translateToEnglish:
            return "Task mode: TRANSLATION ONLY. You must translate the text into English. Pure correction in the original language is forbidden."
        }
    }

    private func retryInstruction(for action: TextTransformationAction, isRetry: Bool) -> String? {
        guard isRetry else { return nil }
        switch action {
        case .correct:
            return "Important: your previous answer appeared incomplete. Return the full corrected chunk only."
        case .translateToEnglish:
            return "Important: your previous answer appeared incomplete. Return the full English translation of the chunk only."
        }
    }

    private func chunkContext(for action: TextTransformationAction, chunkIndex: Int, totalChunks: Int) -> String {
        switch action {
        case .correct:
            return totalChunks > 1
                ? "This is chunk \(chunkIndex) of \(totalChunks) from a larger text. Correct the entire chunk without summarizing it."
                : "Correct the entire text without summarizing it."
        case .translateToEnglish:
            return totalChunks > 1
                ? "This is chunk \(chunkIndex) of \(totalChunks) from a larger text. Translate the entire chunk to English without summarizing it."
                : "Translate the entire text to English without summarizing it."
        }
    }

    private func toneInstruction(for tone: String, action: TextTransformationAction) -> String {
        if tone == "Token-efficient for AI prompts" && action == .correct {
            return """
            Fix spelling, grammar, punctuation, and clarity for text that will be sent to another AI.
            Make it aggressively concise and token-efficient.
            Remove fillers, softeners, redundant connectors, repeated transitions, politeness padding, and any words not needed for comprehension.
            Prefer compact noun-verb phrasing over natural conversational prose.
            It is acceptable if the result sounds telegraphic or slightly cave-man-like, as long as meaning stays clear.
            Keep only the minimum structure needed for clarity and preserve the original intent.
            """
        }

        if tone == "Token-efficient for AI prompts" && action == .translateToEnglish {
            return """
            Translate to English for text that will be sent to another AI.
            Make it aggressively concise and token-efficient.
            Remove fillers, softeners, redundant connectors, repeated transitions, politeness padding, and any words not needed for comprehension.
            Prefer compact noun-verb phrasing over natural conversational prose.
            It is acceptable if the result sounds telegraphic or slightly cave-man-like, as long as meaning stays clear.
            """
        }

        switch action {
        case .correct:
            return "Fix spelling, grammar, punctuation, and clarity using a \(tone) tone."
        case .translateToEnglish:
            return "Translate the text to English using a \(tone) tone."
        }
    }

    private func languageInstruction(for text: String, action: TextTransformationAction) -> String {
        let detectedLanguage = LanguageHeuristics().dominantLanguage(in: text)

        switch action {
        case .correct:
            switch detectedLanguage {
            case .english:
                return "The input is primarily in English. Keep the output in English. Apply the requested tone without changing the language."
            case .spanish:
                return "The input is primarily in Spanish. Keep the output in Spanish. Apply the requested tone without changing the language."
            case .unknown:
                return "Keep the output in the same language as the input. If the text intentionally mixes languages, preserve those language choices instead of normalizing everything into another language."
            }
        case .translateToEnglish:
            switch detectedLanguage {
            case .english:
                return "The input is already primarily in English. Keep the final output in natural English and use the requested tone as a style guide."
            case .spanish:
                return "The input is primarily in Spanish. Translate it fully into English. Use the requested tone only as style guidance after translating."
            case .unknown:
                return "Translate all natural-language content into English. Use the requested tone only as style guidance after translating."
            }
        }
    }

    private func transformationGuardrail(for action: TextTransformationAction) -> String {
        switch action {
        case .correct:
            return """
            Do not translate the text.
            Do not change the language.
            Tone must affect style only, never the language of the answer.
            If the input contains Spanish, English, or a mix of both, preserve that language choice unless there is an obvious typo inside the same language.
            """
        case .translateToEnglish:
            return """
            Translate everything to natural English while preserving intent.
            Do not explain the translation and do not keep the original language.
            Leave code, URLs, emails, and identifiers untouched unless they are natural-language prose.
            If a sentence is already in English, keep it in English and still return one final English-only result.
            """
        }
    }

    private func outputInstruction(for action: TextTransformationAction) -> String {
        switch action {
        case .correct:
            return "Return only the corrected text."
        case .translateToEnglish:
            return "Return only the English translation."
        }
    }
}
