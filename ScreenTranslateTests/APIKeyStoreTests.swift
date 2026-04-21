import XCTest
@testable import ScreenTranslate

final class APIKeyStoreTests: XCTestCase {
    func test读取不到值时返回nil() throws {
        let client = InMemoryKeychainClient()
        let store = APIKeyStore(client: client)

        XCTAssertNil(try store.load())
    }

    func test保存后可以重新读取() throws {
        let client = InMemoryKeychainClient()
        let store = APIKeyStore(client: client)

        try store.save("sk-test")

        XCTAssertEqual(try store.load(), "sk-test")
    }

    func test保存时会去掉首尾空白() throws {
        let client = InMemoryKeychainClient()
        let store = APIKeyStore(client: client)

        try store.save("  \n sk-test \t ")

        XCTAssertEqual(try store.load(), "sk-test")
        XCTAssertEqual(client.rawValue(for: dashScopeAPIKey), "sk-test")
    }

    func test再次保存会覆盖旧值() throws {
        let client = InMemoryKeychainClient()
        let store = APIKeyStore(client: client)

        try store.save("sk-old")
        try store.save("sk-new")

        XCTAssertEqual(try store.load(), "sk-new")
    }

    func test删除后无法再读取() throws {
        let client = InMemoryKeychainClient()
        let store = APIKeyStore(client: client)

        try store.save("sk-test")
        try store.delete()

        XCTAssertNil(try store.load())
    }

    func test使用固定的DashScopeKeychain条目() throws {
        let client = RecordingKeychainClient()
        let store = APIKeyStore(client: client)

        _ = try store.load()
        try store.save("sk-test")
        try store.delete()

        let expectedItem = KeychainItem(
            service: "com.liangcai.ScreenTranslate",
            account: "dashscope.api-key"
        )
        XCTAssertEqual(client.loadedItems, [expectedItem])
        XCTAssertEqual(client.savedEntries.map(\.item), [expectedItem])
        XCTAssertEqual(client.deletedItems, [expectedItem])
    }

    func test读取到仅空白值时返回nil() throws {
        let client = InMemoryKeychainClient()
        client.seed(" \n\t ", for: dashScopeAPIKey)
        let store = APIKeyStore(client: client)

        XCTAssertNil(try store.load())
    }

    func test保存仅空白值时会抛错且不会写入() {
        let client = InMemoryKeychainClient()
        let store = APIKeyStore(client: client)

        XCTAssertThrowsError(try store.save(" \n\t "))
        XCTAssertTrue(client.isEmpty)
    }

    func test读取时会透传client错误() {
        let client = ThrowingKeychainClient(loadError: StubError.loadFailure)
        let store = APIKeyStore(client: client)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? StubError, .loadFailure)
        }
    }

    func test保存时会透传client错误() {
        let client = ThrowingKeychainClient(saveError: StubError.saveFailure)
        let store = APIKeyStore(client: client)

        XCTAssertThrowsError(try store.save("sk-test")) { error in
            XCTAssertEqual(error as? StubError, .saveFailure)
        }
    }

    func test删除时会透传client错误() {
        let client = ThrowingKeychainClient(deleteError: StubError.deleteFailure)
        let store = APIKeyStore(client: client)

        XCTAssertThrowsError(try store.delete()) { error in
            XCTAssertEqual(error as? StubError, .deleteFailure)
        }
    }
}

private final class InMemoryKeychainClient: KeychainClient {
    private var storage: [KeychainItem: String] = [:]

    func load(item: KeychainItem) throws -> String? {
        storage[item]
    }

    func save(_ value: String, item: KeychainItem) throws {
        storage[item] = value
    }

    func delete(item: KeychainItem) throws {
        storage[item] = nil
    }

    func seed(_ value: String, for item: KeychainItem) {
        storage[item] = value
    }

    func rawValue(for item: KeychainItem) -> String? {
        storage[item]
    }

    var isEmpty: Bool {
        storage.isEmpty
    }
}

private final class RecordingKeychainClient: KeychainClient {
    private(set) var loadedItems: [KeychainItem] = []
    private(set) var savedEntries: [(item: KeychainItem, value: String)] = []
    private(set) var deletedItems: [KeychainItem] = []

    func load(item: KeychainItem) throws -> String? {
        loadedItems.append(item)
        return nil
    }

    func save(_ value: String, item: KeychainItem) throws {
        savedEntries.append((item: item, value: value))
    }

    func delete(item: KeychainItem) throws {
        deletedItems.append(item)
    }
}

private final class ThrowingKeychainClient: KeychainClient {
    private let loadError: Error?
    private let saveError: Error?
    private let deleteError: Error?

    init(loadError: Error? = nil, saveError: Error? = nil, deleteError: Error? = nil) {
        self.loadError = loadError
        self.saveError = saveError
        self.deleteError = deleteError
    }

    func load(item _: KeychainItem) throws -> String? {
        if let loadError {
            throw loadError
        }
        return nil
    }

    func save(_ value: String, item _: KeychainItem) throws {
        if let saveError {
            throw saveError
        }
    }

    func delete(item _: KeychainItem) throws {
        if let deleteError {
            throw deleteError
        }
    }
}

private enum StubError: Error, Equatable {
    case loadFailure
    case saveFailure
    case deleteFailure
}

private let dashScopeAPIKey = KeychainItem(
    service: "com.liangcai.ScreenTranslate",
    account: "dashscope.api-key"
)
