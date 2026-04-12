import Foundation

struct CorrectionPrompt {
    let instructions: String
    let text: String
}

struct PromptBuilder {
    func buildPrompt(text: String, tone: String, action: TextTransformationAction, chunkIndex: Int, totalChunks: Int, isRetry: Bool) -> CorrectionPrompt {
        let chunkContext = chunkContext(for: action, chunkIndex: chunkIndex, totalChunks: totalChunks)
        let retryContext = isRetry
            ? "Important: your previous answer appeared incomplete. Return the full corrected chunk only."
            : nil
        let toneInstruction = toneInstruction(for: tone, action: action)

        let lines = [
            chunkContext,
            retryContext,
            toneInstruction,
            transformationGuardrail(for: action),
            "Do not summarize, censor, explain, add headings, or wrap the answer in code fences.",
            "Preserve the original meaning, paragraph breaks, lists, and line structure.",
            outputInstruction(for: action)
        ].compactMap { $0 }

        return CorrectionPrompt(instructions: lines.joined(separator: "\n"), text: text)
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

    private func transformationGuardrail(for action: TextTransformationAction) -> String {
        switch action {
        case .correct:
            return """
            Do not translate the text.
            Do not change the language.
            """
        case .translateToEnglish:
            return """
            Translate everything to natural English while preserving intent.
            Do not explain the translation and do not keep the original language.
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
