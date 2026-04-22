import Foundation

struct ConsoleReporter: OCRReporting {
    func report(_ report: OCRReport) {
        if let imagePath = report.imagePath {
            print("OCR image path: \(imagePath)")
        }

        switch report {
        case let .translated(text, _):
            print("=== Translation Result ===")
            print(text)
            print("=== End Translation Result ===")
        case let .translatedScreenshot(result, _):
            print("=== In-Place Translation Result ===")
            print("image size: \(Int(result.imageSize.width))x\(Int(result.imageSize.height))")
            for line in result.lines {
                print(line.translatedText)
            }
            print("=== End In-Place Translation Result ===")
        case .noText:
            print("No text recognized.")
        case let .failure(message, _):
            print("OCR failed: \(message)")
        case .cancelled:
            print("Capture cancelled.")
        }
    }
}

private extension OCRReport {
    var imagePath: String? {
        switch self {
        case let .translated(_, imagePath):
            return imagePath
        case let .translatedScreenshot(_, imagePath):
            return imagePath
        case let .noText(imagePath):
            return imagePath
        case let .failure(_, imagePath):
            return imagePath
        case .cancelled:
            return nil
        }
    }
}
