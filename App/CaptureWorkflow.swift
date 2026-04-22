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
    func recognizeLayout(in image: CGImage) async throws -> OCRLayoutResult
}

extension TextRecognizing {
    func recognizeStrings(in image: CGImage) async throws -> [String] {
        try await recognizeLayout(in: image).lines.map(\.text)
    }
}

struct TranslatedTextLine: Equatable {
    let sourceText: String
    let translatedText: String
    let boundingBox: CGRect
    let sourceTokens: [OCRTextToken]

    init(
        sourceText: String,
        translatedText: String,
        boundingBox: CGRect,
        sourceTokens: [OCRTextToken] = []
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.boundingBox = boundingBox
        self.sourceTokens = sourceTokens
    }
}

struct TranslatedScreenshotResult: Equatable {
    let image: CGImage
    let lines: [TranslatedTextLine]

    var imageSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    static func == (lhs: TranslatedScreenshotResult, rhs: TranslatedScreenshotResult) -> Bool {
        lhs.image.width == rhs.image.width
            && lhs.image.height == rhs.image.height
            && lhs.lines == rhs.lines
    }
}

enum OCRReport: Equatable {
    case translated(String, imagePath: String?)
    case translatedScreenshot(TranslatedScreenshotResult, imagePath: String?)
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
            let layout = try await recognizer.recognizeLayout(in: image)
            guard !layout.lines.isEmpty else {
                reporter.report(.noText(imagePath: imagePath))
                return
            }

            onBeginTranslation()
            let translatedLines = try await translate(layout.lines)
            reporter.report(
                .translatedScreenshot(
                    TranslatedScreenshotResult(image: image, lines: translatedLines),
                    imagePath: imagePath
                )
            )
        } catch let error as OCRServiceError where error == .noTextRecognized {
            reporter.report(.noText(imagePath: imagePath))
        } catch let error as QwenMTTranslationServiceError {
            reporter.report(.failure(message(for: error), imagePath: imagePath))
        } catch {
            reporter.report(.failure(error.localizedDescription, imagePath: imagePath))
        }
    }

    private func translate(_ lines: [OCRTextLine]) async throws -> [TranslatedTextLine] {
        var translatedLines: [TranslatedTextLine] = []
        translatedLines.reserveCapacity(lines.count)

        for line in lines {
            let translatedText = try await translator.translate(
                line.text,
                targetLanguageCode: targetLanguageCodeProvider()
            )
            translatedLines.append(
                TranslatedTextLine(
                    sourceText: line.text,
                    translatedText: translatedText,
                    boundingBox: line.boundingBox,
                    sourceTokens: line.tokens
                )
            )
        }

        return translatedLines
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
