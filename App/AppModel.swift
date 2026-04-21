import Foundation

@MainActor
final class AppModel: ObservableObject {
    let translationConfigurationStore: TranslationConfigurationStore

    private let loadAPIKey: () throws -> String?
    private let saveAPIKeyClosure: (String) throws -> Void
    private let deleteAPIKeyClosure: () throws -> Void

    @Published var apiKeyInput = ""
    @Published var targetLanguageCode: String {
        didSet {
            translationConfigurationStore.targetLanguageCode = targetLanguageCode
        }
    }

    @Published var screenshotShortcut: ScreenshotShortcut {
        didSet {
            translationConfigurationStore.screenshotShortcut = screenshotShortcut
        }
    }

    @Published private(set) var hasStoredAPIKey: Bool
    @Published private(set) var statusMessage: String

    init(
        translationConfigurationStore: TranslationConfigurationStore = TranslationConfigurationStore(),
        loadAPIKey: @escaping () throws -> String? = { try APIKeyStore().load() },
        saveAPIKey: @escaping (String) throws -> Void = { try APIKeyStore().save($0) },
        deleteAPIKey: @escaping () throws -> Void = { try APIKeyStore().delete() }
    ) {
        self.translationConfigurationStore = translationConfigurationStore
        self.loadAPIKey = loadAPIKey
        self.saveAPIKeyClosure = saveAPIKey
        self.deleteAPIKeyClosure = deleteAPIKey
        self.targetLanguageCode = translationConfigurationStore.targetLanguageCode
        self.screenshotShortcut = translationConfigurationStore.screenshotShortcut

        let storedKey = try? loadAPIKey()
        self.hasStoredAPIKey = storedKey != nil
        self.statusMessage = storedKey == nil
            ? "DashScope API key not configured."
            : "DashScope API key saved."
    }

    func saveAPIKey() {
        let trimmedValue = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if trimmedValue.isEmpty {
                try deleteAPIKeyClosure()
                apiKeyInput = ""
                hasStoredAPIKey = false
                statusMessage = "DashScope API key not configured."
                return
            }

            try saveAPIKeyClosure(trimmedValue)
            apiKeyInput = ""
            hasStoredAPIKey = true
            statusMessage = "DashScope API key saved."
        } catch {
            statusMessage = "Failed to save DashScope API key."
        }
    }
}
