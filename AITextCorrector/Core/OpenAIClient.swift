import Foundation

enum OpenAIClientError: LocalizedError {
    case invalidResponse
    case emptyContent
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "La respuesta de OpenAI no tuvo el formato esperado."
        case .emptyContent:
            return "OpenAI no devolvió un texto corregido válido."
        case .apiError(let statusCode, let message):
            return "Error de OpenAI (\(statusCode)): \(message)"
        }
    }
}

final class OpenAIClient: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func requestCorrection(
        apiKey: String,
        model: String,
        prompt: CorrectionPrompt,
        temperature: Double,
        maxOutputTokens: Int
    ) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "developer", content: prompt.instructions),
                .init(role: "user", content: prompt.text)
            ],
            temperature: temperature,
            maxTokens: maxOutputTokens
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw OpenAIClientError.apiError(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        let payload = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = payload.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw OpenAIClientError.emptyContent
        }
        return content
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
