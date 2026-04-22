import Foundation

protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {}

enum QwenMTTranslationServiceError: Error, Equatable {
    case missingAPIKey
    case invalidResponse
    case invalidStatusCode(Int, message: String?)
    case emptyResponseContent
}

final class QwenMTTranslationService: TranslationService, Sendable {
    private let session: any HTTPSession
    private let apiKeyProvider: @Sendable () throws -> String?
    private let baseURL: URL

    init(
        session: any HTTPSession = URLSession.shared,
        apiKeyProvider: @escaping @Sendable () throws -> String?,
        baseURL: URL = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
        self.baseURL = baseURL
    }

    func translate(_ text: String, targetLanguageCode: String) async throws -> String {
        guard
            let apiKey = try apiKeyProvider()?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty
        else {
            throw QwenMTTranslationServiceError.missingAPIKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TranslationRequest(
                model: "qwen-mt-flash",
                messages: [
                    TranslationRequest.Message(role: "user", content: text),
                ],
                translationOptions: TranslationRequest.TranslationOptions(
                    sourceLanguage: "auto",
                    targetLanguage: targetLanguageCode
                )
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QwenMTTranslationServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = Self.errorMessage(from: data)
            throw QwenMTTranslationServiceError.invalidStatusCode(
                httpResponse.statusCode,
                message: message
            )
        }

        let decodedResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
        guard
            let translatedText = decodedResponse.choices.first?.message.content?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !translatedText.isEmpty
        else {
            throw QwenMTTranslationServiceError.emptyResponseContent
        }

        return translatedText
    }

    private static func errorMessage(from data: Data) -> String? {
        let rawMessage = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawMessage, !rawMessage.isEmpty else {
            return nil
        }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data) {
            if let extracted = extractMessage(from: jsonObject) {
                return extracted
            }
        }

        return rawMessage
    }

    private static func extractMessage(from value: Any) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            if let nestedData = trimmed.data(using: .utf8),
               let nestedObject = try? JSONSerialization.jsonObject(with: nestedData),
               let nestedMessage = extractMessage(from: nestedObject) {
                return nestedMessage
            }

            return trimmed
        }

        if let dictionary = value as? [String: Any] {
            if let message = dictionary["message"] as? String,
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            for key in ["error", "error_message", "detail"] {
                if let nested = dictionary[key],
                   let nestedMessage = extractMessage(from: nested) {
                    return nestedMessage
                }
            }
        }

        if let array = value as? [Any] {
            for element in array {
                if let message = extractMessage(from: element) {
                    return message
                }
            }
        }

        return nil
    }
}

private struct TranslationRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct TranslationOptions: Encodable {
        let sourceLanguage: String
        let targetLanguage: String

        private enum CodingKeys: String, CodingKey {
            case sourceLanguage = "source_lang"
            case targetLanguage = "target_lang"
        }
    }

    let model: String
    let messages: [Message]
    let translationOptions: TranslationOptions

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case translationOptions = "translation_options"
    }
}

private struct TranslationResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
