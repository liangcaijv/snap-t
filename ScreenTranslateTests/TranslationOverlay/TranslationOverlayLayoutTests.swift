import CoreGraphics
import XCTest
@testable import ScreenTranslate

final class TranslationOverlayLayoutTests: XCTestCase {
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
