import CoreGraphics
import XCTest
@testable import ScreenTranslate

final class OCRServiceTests: XCTestCase {
    func test排序逻辑不依赖主线程actor() {
        let lines = [
            OCRTextLine(text: "B", boundingBox: CGRect(x: 0.5, y: 0.7, width: 0.2, height: 0.1)),
            OCRTextLine(text: "A", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.1)),
            OCRTextLine(text: "C", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.1)),
        ]

        let normalized = OCRService.normalize(lines)

        XCTAssertEqual(normalized.map(\.text), ["A", "B", "C"])
    }

    func test第二轮fallback会在结果更可读时覆盖首轮结果() async throws {
        let image = makeImage()
        let service = OCRService { _, configuration in
            if configuration.automaticallyDetectsLanguage {
                return [
                    OCRTextLine(text: "Following my completion of undergraduate studies", boundingBox: .zero),
                ]
            }

            return [
                OCRTextLine(text: "550n+", boundingBox: .zero),
            ]
        }

        let result = try await service.recognizeStrings(in: image)

        XCTAssertEqual(result, ["Following my completion of undergraduate studies"])
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
