import Foundation
import XCTest
@testable import ScreenTranslate

@MainActor
final class AppModelTests: XCTestCase {
    func test缺失APIKey时会暴露未配置状态() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = TranslationConfigurationStore(defaults: defaults)
        let model = AppModel(
            translationConfigurationStore: store,
            loadAPIKey: { nil },
            saveAPIKey: { _ in },
            deleteAPIKey: {}
        )

        XCTAssertFalse(model.hasStoredAPIKey)
        XCTAssertEqual(model.statusMessage, "DashScope API key not configured.")
        XCTAssertEqual(model.targetLanguageCode, "en")
    }

    func test打开设置前会先激活应用() {
        var events: [String] = []
        let presenter = SettingsPresenter(
            activateApp: {
                events.append("activate")
            },
            openSettings: {
                events.append("open")
            }
        )

        presenter.present()

        XCTAssertEqual(events, ["activate", "open"])
    }
}
