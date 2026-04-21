import CoreGraphics
import XCTest
@testable import ScreenTranslate

final class SelectionGeometryTests: XCTestCase {
    func test右侧副屏窗口使用零起点本地bounds() {
        let globalFrame = CGRect(x: 1728, y: 0, width: 2560, height: 1440)

        let bounds = SelectionGeometry.windowBounds(forScreenFrame: globalFrame)

        XCTAssertEqual(bounds.origin, CGPoint.zero)
        XCTAssertEqual(bounds.size, globalFrame.size)
    }

    func test本地选区会转换为带副屏偏移的全局锚点() {
        let screenFrame = CGRect(x: 1728, y: 0, width: 2560, height: 1440)
        let localSelection = CGRect(x: 120, y: 80, width: 400, height: 300)

        let anchorRect = SelectionGeometry.globalAnchorRect(
            forLocalSelection: localSelection,
            screenFrame: screenFrame
        )

        XCTAssertEqual(anchorRect.origin.x, 1848)
        XCTAssertEqual(anchorRect.origin.y, 80)
        XCTAssertEqual(anchorRect.size, localSelection.size)
    }

    func test会把本地选区转换为Retina像素坐标() {
        let rect = SelectionGeometry.displayCaptureRect(
            forLocalSelection: CGRect(x: 100, y: 200, width: 300, height: 100),
            screenSize: CGSize(width: 1440, height: 900),
            pixelSize: CGSize(width: 2880, height: 1800)
        )

        XCTAssertEqual(rect.origin.x, 200)
        XCTAssertEqual(rect.origin.y, 400)
        XCTAssertEqual(rect.width, 600)
        XCTAssertEqual(rect.height, 200)
    }
}
