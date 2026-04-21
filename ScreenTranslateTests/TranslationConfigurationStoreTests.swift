import XCTest
@testable import ScreenTranslate

@MainActor
final class TranslationConfigurationStoreTests: XCTestCase {
    private static let targetLanguageDefaultsKey = "translation.targetLanguageCode"

    func test默认目标语言是英文() {
        let defaults = makeDefaults(testName: #function)
        let store = TranslationConfigurationStore(defaults: defaults)

        XCTAssertEqual(store.targetLanguageCode, "en")
    }

    func test可以持久化目标语言代码() {
        let defaults = makeDefaults(testName: #function)
        let store = TranslationConfigurationStore(defaults: defaults)

        store.targetLanguageCode = "ja"

        let reloaded = TranslationConfigurationStore(defaults: defaults)
        XCTAssertEqual(reloaded.targetLanguageCode, "ja")
    }

    func test持久化的非法目标语言会回退到英文() {
        let defaults = makeDefaults(testName: #function)
        defaults.set("invalid-code", forKey: Self.targetLanguageDefaultsKey)

        let store = TranslationConfigurationStore(defaults: defaults)

        XCTAssertEqual(store.targetLanguageCode, "en")
        XCTAssertEqual(defaults.string(forKey: Self.targetLanguageDefaultsKey), "en")
    }

    func test设置非法目标语言会立即回退到英文() {
        let defaults = makeDefaults(testName: #function)
        let store = TranslationConfigurationStore(defaults: defaults)

        store.targetLanguageCode = "invalid-code"

        XCTAssertEqual(store.targetLanguageCode, "en")
        XCTAssertEqual(defaults.string(forKey: Self.targetLanguageDefaultsKey), "en")
    }

    func test支持语言列表会把常用语言排在前面() {
        let languages = SupportedTranslationLanguage.all

        XCTAssertEqual(languages.count, 92)
        XCTAssertEqual(Array(languages.prefix(10).map(\.code)), ["en", "zh", "zh_tw", "ru", "ja", "ko", "es", "fr", "pt", "de"])
        XCTAssertEqual(Set(languages.map(\.code)).count, languages.count)
        XCTAssertEqual(SupportedTranslationLanguage.english, languages.first)
        XCTAssertTrue(["yue", "arz", "acm", "apc", "ajp", "acq", "ary", "ars", "vec", "war", "pag", "ast", "ceb", "mai"].allSatisfy { code in
            languages.contains(where: { $0.code == code })
        })
    }

    private func makeDefaults(testName: String) -> UserDefaults {
        let suiteName = "TranslationConfigurationStoreTests.\(testName)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
