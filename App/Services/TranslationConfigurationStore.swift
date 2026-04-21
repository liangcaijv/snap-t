import Combine
import Foundation

@MainActor
final class TranslationConfigurationStore: ObservableObject {
    private enum Keys {
        static let targetLanguageCode = "translation.targetLanguageCode"
        static let screenshotShortcut = "translation.screenshotShortcut"
    }

    private let defaults: UserDefaults

    @Published var targetLanguageCode: String {
        didSet {
            persistSanitizedTargetLanguageCode()
        }
    }

    @Published var screenshotShortcut: ScreenshotShortcut {
        didSet {
            persistScreenshotShortcut()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let persistedCode = defaults.string(forKey: Keys.targetLanguageCode)
        let sanitizedCode = Self.sanitizedTargetLanguageCode(persistedCode)
        targetLanguageCode = sanitizedCode
        screenshotShortcut = Self.persistedScreenshotShortcut(from: defaults) ?? .default
        defaults.set(sanitizedCode, forKey: Keys.targetLanguageCode)
    }

    private func persistSanitizedTargetLanguageCode() {
        let sanitizedCode = Self.sanitizedTargetLanguageCode(targetLanguageCode)
        guard sanitizedCode == targetLanguageCode else {
            targetLanguageCode = sanitizedCode
            return
        }

        defaults.set(sanitizedCode, forKey: Keys.targetLanguageCode)
    }

    private static func sanitizedTargetLanguageCode(_ code: String?) -> String {
        guard let code, SupportedTranslationLanguage.supportedCodes.contains(code) else {
            return SupportedTranslationLanguage.english.code
        }

        return code
    }

    private func persistScreenshotShortcut() {
        if let data = try? ShortcutCodec.encode(screenshotShortcut) {
            defaults.set(data, forKey: Keys.screenshotShortcut)
        }
    }

    private static func persistedScreenshotShortcut(from defaults: UserDefaults) -> ScreenshotShortcut? {
        guard
            let data = defaults.data(forKey: Keys.screenshotShortcut),
            let shortcut = try? ShortcutCodec.decode(data)
        else {
            return nil
        }

        return shortcut
    }
}
