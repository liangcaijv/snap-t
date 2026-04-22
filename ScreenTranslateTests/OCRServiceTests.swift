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

    func testrecognizeLayout会返回排序后的结构化结果() async throws {
        let image = makeImage()
        let expected = [
            OCRTextLine(text: "B", boundingBox: CGRect(x: 0.5, y: 0.7, width: 0.2, height: 0.1)),
            OCRTextLine(text: "A", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.1)),
            OCRTextLine(text: "C", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.1)),
        ]
        let service = OCRService { _, _ in
            expected
        }

        let result = try await service.recognizeLayout(in: image)

        XCTAssertEqual(result.lines.map(\.text), ["A", "B", "C"])
        XCTAssertEqual(
            result.lines.map(\.boundingBox),
            [
                CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.1),
                CGRect(x: 0.5, y: 0.7, width: 0.2, height: 0.1),
                CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
            ]
        )
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

    func test会把英文单词和中文字符切成细粒度token() {
        let descriptors = OCRService.tokenDescriptors(in: "Open tabs 打开标签页")

        XCTAssertEqual(descriptors.map(\.text), ["Open", "tabs", "打", "开", "标", "签", "页"])
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
