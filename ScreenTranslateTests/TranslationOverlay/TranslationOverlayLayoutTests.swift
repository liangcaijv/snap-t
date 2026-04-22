import CoreGraphics
import XCTest
@testable import ScreenTranslate

final class TranslationOverlayLayoutTests: XCTestCase {
    func test会把归一化文本框转换为图片坐标() {
        let rect = TranslatedScreenshotLayout.imageRect(
            for: CGRect(x: 0.1, y: 0.6, width: 0.3, height: 0.2),
            imageSize: CGSize(width: 1000, height: 500)
        )

        XCTAssertEqual(rect, CGRect(x: 100, y: 100, width: 300, height: 100))
    }

    func test会为文本区域生成带内边距的覆盖框() {
        let coverRect = TranslatedScreenshotLayout.coverRect(
            for: CGRect(x: 100, y: 80, width: 200, height: 40),
            padding: 6
        )

        XCTAssertEqual(coverRect, CGRect(x: 94, y: 77, width: 212, height: 46))
    }

    func test会在目标区域内选择合适字号() {
        let large = TranslatedScreenshotLayout.fittedFontSize(
            for: "Short",
            in: CGRect(x: 0, y: 0, width: 180, height: 28)
        )
        let small = TranslatedScreenshotLayout.fittedFontSize(
            for: "A much longer translated sentence that has to wrap into the original area",
            in: CGRect(x: 0, y: 0, width: 180, height: 28)
        )

        XCTAssertGreaterThanOrEqual(large, small)
        XCTAssertGreaterThanOrEqual(small, 8)
    }

    func test图内回填按整行排版而不是token拆分() {
        let placement = TranslatedScreenshotLayout.linePlacement(
            for: TranslatedTextLine(
                sourceText: "Open tabs",
                translatedText: "打开标签页",
                boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.3, height: 0.2),
                sourceTokens: [
                    OCRTextToken(text: "Open", boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.12, height: 0.2)),
                    OCRTextToken(text: "tabs", boundingBox: CGRect(x: 0.24, y: 0.6, width: 0.16, height: 0.2)),
                ]
            ),
            imageSize: CGSize(width: 1000, height: 500)
        )

        XCTAssertEqual(placement.text, "打开标签页")
        XCTAssertEqual(placement.rect, CGRect(x: 100, y: 100, width: 300, height: 100))
    }

    func test初始frame会锚定到截图区域并保持最小尺寸() {
        let frame = TranslationOverlayLayout.initialFrame(
            for: CGRect(x: 100, y: 200, width: 80, height: 40)
        )

        XCTAssertEqual(frame.origin.x, 100)
        XCTAssertEqual(frame.origin.y, 200)
        XCTAssertEqual(frame.width, 220)
        XCTAssertEqual(frame.height, 120)
    }

    func test大截图区域会保留原始尺寸() {
        let frame = TranslationOverlayLayout.initialFrame(
            for: CGRect(x: 10, y: 20, width: 320, height: 180),
            within: CGRect(x: 0, y: 0, width: 2000, height: 2000)
        )

        XCTAssertEqual(frame, CGRect(x: 10, y: 20, width: 320, height: 180))
    }

    func test最小尺寸展开后会被限制在可见区域内() {
        let frame = TranslationOverlayLayout.initialFrame(
            for: CGRect(x: 760, y: 560, width: 40, height: 20),
            within: CGRect(x: 0, y: 0, width: 800, height: 600)
        )

        XCTAssertEqual(frame.maxX, 800)
        XCTAssertEqual(frame.maxY, 600)
        XCTAssertEqual(frame.width, 220)
        XCTAssertEqual(frame.height, 120)
    }

    func test更新frame时会在超长内容下限制到可见区域() {
        let frame = TranslationOverlayLayout.updatedFrame(
            from: CGRect(x: 40, y: 40, width: 220, height: 120),
            state: .translated(String(repeating: "Long translation ", count: 200)),
            within: CGRect(x: 0, y: 0, width: 500, height: 300)
        )

        XCTAssertEqual(frame.maxX, 500)
        XCTAssertEqual(frame.maxY, 300)
        XCTAssertLessThanOrEqual(frame.width, 500)
        XCTAssertLessThanOrEqual(frame.height, 300)
    }
}
