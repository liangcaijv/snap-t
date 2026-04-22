import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, OCRReporting {
    private let overlayController = OverlayWindowController()
    private let translationOverlayController = TranslationOverlayController()
    private let windowVisibilityController = CaptureWindowVisibilityController()
    private let shortcutManager = ShortcutManager()
    private var translationConfigurationStore = TranslationConfigurationStore()
    private var shortcutCancellable: AnyCancellable?
    private lazy var workflow = CaptureWorkflow(
        capturer: overlayController,
        recognizer: OCRService(),
        translator: QwenMTTranslationService(
            apiKeyProvider: {
                try APIKeyStore().load()
            }
        ),
        reporter: self,
        targetLanguageCodeProvider: { [weak self] in
            self?.translationConfigurationStore.targetLanguageCode ?? SupportedTranslationLanguage.english.code
        },
        onBeginTranslation: { [weak self] in
            self?.showTranslationLoading()
        },
        onPrepareCapture: { [weak self] in
            self?.hideWindowsForCapture()
        },
        onFinishCapture: { [weak self] in
            self?.restoreWindowsAfterCapture()
        }
    )

    func configure(translationConfigurationStore: TranslationConfigurationStore) {
        self.translationConfigurationStore = translationConfigurationStore
        shortcutCancellable = translationConfigurationStore.$screenshotShortcut.sink { [weak self] shortcut in
            self?.registerShortcut(shortcut)
        }
    }

    func startCapture() {
        guard hasConfiguredAPIKey() else {
            NSSound.beep()
            return
        }

        translationOverlayController.dismiss()
        workflow.startCapture()
    }

    func report(_ report: OCRReport) {
        switch report {
        case let .translated(text, _):
            translationOverlayController.showTranslation(text)
        case let .translatedScreenshot(result, _):
            translationOverlayController.showTranslatedScreenshot(result)
        case .noText:
            translationOverlayController.showNoText()
        case let .failure(message, _):
            translationOverlayController.showFailure(message)
        case .cancelled:
            translationOverlayController.dismiss()
        }
    }

    private func hideWindowsForCapture() {
        windowVisibilityController.hideTrackedWindows(in: NSApp.windows)
    }

    private func restoreWindowsAfterCapture() {
        windowVisibilityController.restoreTrackedWindows()
    }

    private func hasConfiguredAPIKey() -> Bool {
        guard let _ = try? APIKeyStore().load() else {
            return false
        }
        return true
    }

    private func registerShortcut(_ shortcut: ScreenshotShortcut) {
        do {
            try shortcutManager.register(shortcut: shortcut) { [weak self] in
                Task { @MainActor in
                    self?.startCapture()
                }
            }
        } catch {
            NSLog("Failed to register screenshot shortcut: \(error.localizedDescription)")
        }
    }

    private func showTranslationLoading() {
        guard let lastCaptureRect = overlayController.lastCaptureRect else {
            return
        }

        translationOverlayController.presentLoading(anchoredTo: lastCaptureRect)
    }
}
