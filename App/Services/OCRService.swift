import CoreGraphics
import Foundation
@preconcurrency import Vision

struct OCRTextLine: Equatable {
    let text: String
    let boundingBox: CGRect
}

struct OCRRecognitionConfiguration: Equatable, Sendable {
    let recognitionLanguages: [String]
    let automaticallyDetectsLanguage: Bool
    let usesLanguageCorrection: Bool

    static let primary = OCRRecognitionConfiguration(
        recognitionLanguages: ["zh-Hans", "zh-Hant", "en-US"],
        automaticallyDetectsLanguage: false,
        usesLanguageCorrection: false
    )

    static let fallback = OCRRecognitionConfiguration(
        recognitionLanguages: ["en-US"],
        automaticallyDetectsLanguage: true,
        usesLanguageCorrection: true
    )
}

enum OCRServiceError: Error, Equatable {
    case noTextRecognized
}

final class OCRService: TextRecognizing, @unchecked Sendable {
    private let performRecognition: @Sendable (CGImage, OCRRecognitionConfiguration) throws -> [OCRTextLine]

    init(
        performRecognition: @escaping @Sendable (CGImage, OCRRecognitionConfiguration) throws -> [OCRTextLine] = OCRService.performRecognition
    ) {
        self.performRecognition = performRecognition
    }

    static func makeRequest(
        configuration: OCRRecognitionConfiguration,
        completionHandler: VNRequestCompletionHandler? = nil
    ) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest(completionHandler: completionHandler)
        request.recognitionLevel = .accurate
        request.recognitionLanguages = configuration.recognitionLanguages
        request.automaticallyDetectsLanguage = configuration.automaticallyDetectsLanguage
        request.usesLanguageCorrection = configuration.usesLanguageCorrection
        return request
    }

    static func normalize(_ lines: [OCRTextLine]) -> [OCRTextLine] {
        lines.sorted {
            if abs($0.boundingBox.minY - $1.boundingBox.minY) < 0.05 {
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            return $0.boundingBox.minY > $1.boundingBox.minY
        }
    }

    static func performRecognition(in image: CGImage, configuration: OCRRecognitionConfiguration) throws -> [OCRTextLine] {
        let request = makeRequest(configuration: configuration)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        let lines = observations.compactMap { observation -> OCRTextLine? in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }

            return OCRTextLine(text: text, boundingBox: observation.boundingBox)
        }

        return normalize(lines)
    }

    func recognizeStrings(in image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let performRecognition = self.performRecognition
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let primaryResult = try? performRecognition(image, .primary)
                    let fallbackResult = try? performRecognition(image, .fallback)
                    let bestLines = Self.chooseBestResult(primary: primaryResult ?? [], fallback: fallbackResult ?? [])

                    guard !bestLines.isEmpty else {
                        continuation.resume(throwing: OCRServiceError.noTextRecognized)
                        return
                    }

                    continuation.resume(returning: bestLines.map(\.text))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func chooseBestResult(primary: [OCRTextLine], fallback: [OCRTextLine]) -> [OCRTextLine] {
        score(for: fallback) > score(for: primary) ? fallback : primary
    }

    private static func score(for lines: [OCRTextLine]) -> Int {
        lines
            .map(\.text)
            .joined(separator: " ")
            .unicodeScalars
            .reduce(0) { partialResult, scalar in
                switch scalar.value {
                case 65...90, 97...122:
                    return partialResult + 3
                case 32:
                    return partialResult + 2
                case 46, 44, 58, 59, 39, 34, 40, 41, 45:
                    return partialResult + 1
                case 48...57:
                    return partialResult - 2
                default:
                    return partialResult - 3
                }
            }
    }
}
