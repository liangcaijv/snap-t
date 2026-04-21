import CoreGraphics
import Foundation

struct CapturedRegion {
    let image: CGImage
}

enum CaptureError: Error, Equatable {
    case cancelled
    case permissionDenied
    case captureFailed
}

@MainActor
protocol ScreenRegionCapturing {
    func present(completion: @escaping (Result<CapturedRegion, CaptureError>) -> Void)
}

protocol TextRecognizing: Sendable {
    func recognizeStrings(in image: CGImage) async throws -> [String]
}

enum OCRReport: Equatable {
    case translated(String, imagePath: String?)
    case noText(imagePath: String?)
    case failure(String, imagePath: String?)
    case cancelled
}

@MainActor
protocol OCRReporting {
    func report(_ report: OCRReport)
}

protocol CapturedImageDebugStoring: Sendable {
    func persist(_ image: CGImage) -> String?
}

@MainActor
final class CaptureWorkflow {
    private let capturer: ScreenRegionCapturing
    private let recognizer: TextRecognizing
    private let translator: TranslationService
    private let reporter: OCRReporting
    private let debugStore: CapturedImageDebugStoring
    private let targetLanguageCodeProvider: () -> String
    private let onBeginTranslation: () -> Void
    private let onPrepareCapture: () -> Void
    private let onFinishCapture: () -> Void

    init(
        capturer: ScreenRegionCapturing,
        recognizer: TextRecognizing,
        translator: TranslationService,
        reporter: OCRReporting,
        debugStore: CapturedImageDebugStoring = CapturedImageDebugStore(),
        targetLanguageCodeProvider: @escaping () -> String = { SupportedTranslationLanguage.english.code },
        onBeginTranslation: @escaping () -> Void = {},
        onPrepareCapture: @escaping () -> Void = {},
        onFinishCapture: @escaping () -> Void = {}
    ) {
        self.capturer = capturer
        self.recognizer = recognizer
        self.translator = translator
        self.reporter = reporter
        self.debugStore = debugStore
        self.targetLanguageCodeProvider = targetLanguageCodeProvider
        self.onBeginTranslation = onBeginTranslation
        self.onPrepareCapture = onPrepareCapture
        self.onFinishCapture = onFinishCapture
    }

    func startCapture() {
        onPrepareCapture()
        capturer.present { [weak self] result in
            Task { @MainActor in
                await self?.handleCaptureResult(result)
            }
        }
    }

    func handleCaptureResult(_ result: Result<CapturedRegion, CaptureError>) async {
        defer {
            onFinishCapture()
        }

        switch result {
        case let .success(capturedRegion):
            await handleCapturedImage(capturedRegion.image)
        case .failure(.cancelled):
            reporter.report(.cancelled)
        case .failure(.permissionDenied):
            reporter.report(.failure("Screen capture permission denied.", imagePath: nil))
        case .failure(.captureFailed):
            reporter.report(.failure("Screenshot capture failed.", imagePath: nil))
        }
    }

    private func handleCapturedImage(_ image: CGImage) async {
        let imagePath = debugStore.persist(image)

        do {
            let strings = try await recognizer.recognizeStrings(in: image)
            guard !strings.isEmpty else {
                reporter.report(.noText(imagePath: imagePath))
                return
            }

            onBeginTranslation()
            let translatedText = try await translator.translate(
                strings.joined(separator: "\n"),
                targetLanguageCode: targetLanguageCodeProvider()
            )
            reporter.report(.translated(translatedText, imagePath: imagePath))
        } catch let error as OCRServiceError where error == .noTextRecognized {
            reporter.report(.noText(imagePath: imagePath))
        } catch let error as QwenMTTranslationServiceError {
            reporter.report(.failure(message(for: error), imagePath: imagePath))
        } catch {
            reporter.report(.failure(error.localizedDescription, imagePath: imagePath))
        }
    }

    private func message(for error: QwenMTTranslationServiceError) -> String {
        switch error {
        case .missingAPIKey:
            return "DashScope API key is not configured."
        case let .invalidStatusCode(_, message):
            return message ?? "Translation request failed."
        case .emptyResponseContent:
            return "Translation response was empty."
        case .invalidResponse:
            return "Translation service returned an invalid response."
        }
    }
}
