import CoreGraphics
import XCTest
@testable import ScreenTranslate

final class SelectionGeometryTests: XCTestCase {
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
