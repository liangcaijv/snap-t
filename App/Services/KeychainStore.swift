import Foundation
import Security

struct KeychainItem: Hashable, Sendable {
    let service: String
    let account: String
}

protocol KeychainClient {
    func load(item: KeychainItem) throws -> String?
    func save(_ value: String, item: KeychainItem) throws
    func delete(item: KeychainItem) throws
}

struct KeychainStore: KeychainClient {
    func load(item: KeychainItem) throws -> String? {
        var query = keychainQuery(for: item)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainStoreError.invalidValueData
            }
            guard let value = String(data: data, encoding: .utf8) else {
                throw KeychainStoreError.invalidValueData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    func save(_ value: String, item: KeychainItem) throws {
        let valueData = Data(value.utf8)
        var addQuery = keychainQuery(for: item)
        addQuery[kSecValueData as String] = valueData

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributesToUpdate = [kSecValueData as String: valueData] as CFDictionary
            let updateStatus = SecItemUpdate(keychainQuery(for: item) as CFDictionary, attributesToUpdate)
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(updateStatus)
            }
        default:
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    func delete(item: KeychainItem) throws {
        let status = SecItemDelete(keychainQuery(for: item) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func keychainQuery(for item: KeychainItem) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: item.service,
            kSecAttrAccount as String: item.account,
        ]
    }
}

enum KeychainStoreError: Error {
    case invalidValueData
    case unexpectedStatus(OSStatus)
}
