import CoreGraphics
import XCTest
@testable import ScreenTranslate

@MainActor
final class CaptureWorkflowTests: XCTestCase {
    func test成功截图后会把翻译文本交给reporter() async {
        let recognizer = StubRecognizer(result: .success(["Hello", "World"]))
        let translator = StubTranslator(result: .success("你好，世界"))
        let reporter = RecordingReporter()
        let workflow = CaptureWorkflow(
            capturer: StubCapturer(),
            recognizer: recognizer,
            translator: translator,
            reporter: reporter,
            debugStore: StubDebugStore(path: "/tmp/ocr-debug.png"),
            targetLanguageCodeProvider: { "zh" }
        )

        await workflow.handleCaptureResult(.success(CapturedRegion(image: makeImage())))

        XCTAssertEqual(translator.requests, [TranslationRequestRecord(text: "Hello\nWorld", targetLanguageCode: "zh")])
        XCTAssertEqual(reporter.reports, [.translated("你好，世界", imagePath: "/tmp/ocr-debug.png")])
    }

    func testOCR没有识别到文本时会上报noText() async {
        let recognizer = StubRecognizer(result: .failure(OCRServiceError.noTextRecognized))
        let translator = StubTranslator(result: .success("unused"))
        let reporter = RecordingReporter()
        let workflow = CaptureWorkflow(
            capturer: StubCapturer(),
            recognizer: recognizer,
            translator: translator,
            reporter: reporter,
            debugStore: StubDebugStore(path: "/tmp/ocr-debug.png"),
            targetLanguageCodeProvider: { "en" }
        )

        await workflow.handleCaptureResult(.success(CapturedRegion(image: makeImage())))

        XCTAssertEqual(reporter.reports, [.noText(imagePath: "/tmp/ocr-debug.png")])
        XCTAssertTrue(translator.requests.isEmpty)
    }

    func test权限缺失时会上报失败() async {
        let recognizer = StubRecognizer(result: .success(["unused"]))
        let translator = StubTranslator(result: .success("unused"))
        let reporter = RecordingReporter()
        let workflow = CaptureWorkflow(
            capturer: StubCapturer(),
            recognizer: recognizer,
            translator: translator,
            reporter: reporter
        )

        await workflow.handleCaptureResult(.failure(.permissionDenied))

        XCTAssertEqual(reporter.reports, [.failure("Screen capture permission denied.", imagePath: nil)])
    }

    func test默认不会持久化截图到磁盘() async {
        let recognizer = StubRecognizer(result: .success(["Hello"]))
        let translator = StubTranslator(result: .success("你好"))
        let reporter = RecordingReporter()
        let workflow = CaptureWorkflow(
            capturer: StubCapturer(),
            recognizer: recognizer,
            translator: translator,
            reporter: reporter
        )

        await workflow.handleCaptureResult(.success(CapturedRegion(image: makeImage())))

        XCTAssertEqual(reporter.reports, [.translated("你好", imagePath: nil)])
    }

    func test缺少APIKey时会上报配置失败() async {
        let recognizer = StubRecognizer(result: .success(["Hello"]))
        let translator = StubTranslator(result: .failure(QwenMTTranslationServiceError.missingAPIKey))
        let reporter = RecordingReporter()
        let workflow = CaptureWorkflow(
            capturer: StubCapturer(),
            recognizer: recognizer,
            translator: translator,
            reporter: reporter,
            debugStore: StubDebugStore(path: "/tmp/ocr-debug.png")
        )

        await workflow.handleCaptureResult(.success(CapturedRegion(image: makeImage())))

        XCTAssertEqual(
            reporter.reports,
            [.failure("DashScope API key is not configured.", imagePath: "/tmp/ocr-debug.png")]
        )
    }

    func test翻译失败时会上报失败() async {
        let recognizer = StubRecognizer(result: .success(["Hello"]))
        let translator = StubTranslator(result: .failure(QwenMTTranslationServiceError.invalidStatusCode(429, message: "rate limited")))
        let reporter = RecordingReporter()
        let workflow = CaptureWorkflow(
            capturer: StubCapturer(),
            recognizer: recognizer,
            translator: translator,
            reporter: reporter,
            debugStore: StubDebugStore(path: "/tmp/ocr-debug.png")
        )

        await workflow.handleCaptureResult(.success(CapturedRegion(image: makeImage())))

        XCTAssertEqual(
            reporter.reports,
            [.failure("rate limited", imagePath: "/tmp/ocr-debug.png")]
        )
    }
}

private final class StubCapturer: ScreenRegionCapturing {
    func present(completion _: @escaping (Result<CapturedRegion, CaptureError>) -> Void) {}
}

private final class StubRecognizer: TextRecognizing, @unchecked Sendable {
    private let result: Result<[String], Error>

    init(result: Result<[String], Error>) {
        self.result = result
    }

    func recognizeStrings(in _: CGImage) async throws -> [String] {
        try result.get()
    }
}

private struct TranslationRequestRecord: Equatable {
    let text: String
    let targetLanguageCode: String
}

private final class StubTranslator: TranslationService, @unchecked Sendable {
    private let result: Result<String, Error>
    private(set) var requests: [TranslationRequestRecord] = []

    init(result: Result<String, Error>) {
        self.result = result
    }

    func translate(_ text: String, targetLanguageCode: String) async throws -> String {
        requests.append(
            TranslationRequestRecord(text: text, targetLanguageCode: targetLanguageCode)
        )
        return try result.get()
    }
}

private final class RecordingReporter: OCRReporting {
    private(set) var reports: [OCRReport] = []

    func report(_ report: OCRReport) {
        reports.append(report)
    }
}

private struct StubDebugStore: CapturedImageDebugStoring {
    let path: String?

    func persist(_ image: CGImage) -> String? {
        path
    }
}

private func makeImage() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 8,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}
