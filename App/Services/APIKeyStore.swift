import Foundation

struct APIKeyStore {
    private let client: KeychainClient
    private let item: KeychainItem

    init(
        client: KeychainClient = KeychainStore(),
        item: KeychainItem = .dashScopeAPIKey
    ) {
        self.client = client
        self.item = item
    }

    func load() throws -> String? {
        try Self.sanitizedKey(from: client.load(item: item))
    }

    func save(_ value: String) throws {
        guard let sanitizedValue = Self.sanitizedKey(from: value) else {
            throw APIKeyStoreError.emptyValue
        }

        try client.save(sanitizedValue, item: item)
    }

    func delete() throws {
        try client.delete(item: item)
    }

    private static func sanitizedKey(from value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

enum APIKeyStoreError: Error {
    case emptyValue
}

private extension KeychainItem {
    static let dashScopeAPIKey = KeychainItem(
        service: "com.liangcai.ScreenTranslate",
        account: "dashscope.api-key"
    )
}
