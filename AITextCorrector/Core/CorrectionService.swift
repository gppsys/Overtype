import Foundation

actor CorrectionService {
    private let openAIClient: OpenAIClient
    private let promptBuilder: PromptBuilder
    private let chunkingService: ChunkingService
    private let riskAssessmentService: RiskAssessmentService
    private let notificationService: NotificationService

    init(
        openAIClient: OpenAIClient,
        promptBuilder: PromptBuilder,
        chunkingService: ChunkingService,
        riskAssessmentService: RiskAssessmentService,
        notificationService: NotificationService
    ) {
        self.openAIClient = openAIClient
        self.promptBuilder = promptBuilder
        self.chunkingService = chunkingService
        self.riskAssessmentService = riskAssessmentService
        self.notificationService = notificationService
    }

    func correctText(_ request: CorrectionRequest, apiKey: String, showNotifications: Bool, onProgress: (@Sendable (Int, Int) -> Void)? = nil) async throws -> CorrectionResult {
        let perRequestLimit = min(chunkingService.maxCharsPerRequest, request.settings.maxInputChars)
        let chunks = chunkingService.splitTextIntoChunks(request.text, maxChars: perRequestLimit)

        if chunks.count > 1 && request.text.count >= chunkingService.longTextNoticeThreshold && showNotifications {
            let verb = request.action == .correct ? "Corrigiendo" : "Traduciendo"
            await notificationService.send(title: "AI Text Corrector", body: "\(verb) texto largo en \(chunks.count) bloques...")
        }

        var correctedChunks: [String] = []
        for (index, chunk) in chunks.enumerated() {
            correctedChunks.append(try await correctChunk(
                chunk,
                request: request,
                apiKey: apiKey,
                chunkIndex: index + 1,
                totalChunks: chunks.count
            ))
            onProgress?(index + 1, chunks.count)
        }

        let correctedText = correctedChunks.joined()
        return CorrectionResult(
            correctedText: correctedText,
            manualReviewReason: riskAssessmentService.assess(originalText: request.text, correctedText: correctedText, action: request.action)
        )
    }

    private func correctChunk(
        _ chunk: String,
        request: CorrectionRequest,
        apiKey: String,
        chunkIndex: Int,
        totalChunks: Int
    ) async throws -> String {
        let whitespace = chunkingService.splitOuterWhitespace(chunk)
        if whitespace.core.isEmpty { return chunk }

        var lastError: Error?
        for attempt in 1...chunkingService.retryAttempts {
            do {
                let prompt = promptBuilder.buildPrompt(
                    text: whitespace.core,
                    tone: request.tone,
                    action: request.action,
                    chunkIndex: chunkIndex,
                    totalChunks: totalChunks,
                    isRetry: attempt > 1
                )

                let rawResponse = try await openAIClient.requestCorrection(
                    apiKey: apiKey,
                    model: request.settings.model,
                    prompt: prompt,
                    temperature: request.settings.temperature,
                    maxOutputTokens: chunkingService.estimateMaxTokens(
                        for: whitespace.core,
                        configuredMaxOutputTokens: request.settings.maxOutputTokens
                    )
                )

                let correctedCore = OutputSanitizer.sanitize(
                    OutputSanitizer.stripCodeFences(rawResponse).trimmingCharacters(in: .whitespacesAndNewlines)
                )

                if let risk = riskAssessmentService.assess(originalText: whitespace.core, correctedText: correctedCore, action: request.action) {
                    throw NSError(domain: "AITextCorrector.Risk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bloque \(chunkIndex)/\(totalChunks): \(risk)"])
                }

                return whitespace.leading + correctedCore + whitespace.trailing
            } catch {
                lastError = error
            }
        }

        throw lastError ?? NSError(domain: "AITextCorrector.Correction", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se pudo corregir el texto."])
    }
}
