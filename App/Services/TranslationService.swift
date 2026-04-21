import Foundation

protocol TranslationService: Sendable {
    func translate(_ text: String, targetLanguageCode: String) async throws -> String
}
