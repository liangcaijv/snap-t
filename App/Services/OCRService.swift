import CoreGraphics
import Foundation
@preconcurrency import Vision

struct OCRTextLine: Equatable {
    let text: String
    let boundingBox: CGRect
    let tokens: [OCRTextToken]

    init(text: String, boundingBox: CGRect, tokens: [OCRTextToken] = []) {
        self.text = text
        self.boundingBox = boundingBox
        self.tokens = tokens
    }
}

struct OCRTextToken: Equatable {
    let text: String
    let boundingBox: CGRect
}

struct OCRTokenDescriptor: Equatable {
    let text: String
    let range: Range<String.Index>
}

struct OCRLayoutResult: Equatable {
    let lines: [OCRTextLine]
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

        let observations = request.results ?? []
        let lines = observations.compactMap { observation -> OCRTextLine? in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            let rawText = candidate.string
            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }

            let tokens = tokenDescriptors(in: rawText).compactMap { descriptor -> OCRTextToken? in
                guard let tokenBox = try? candidate.boundingBox(for: descriptor.range)?.boundingBox else {
                    return nil
                }

                return OCRTextToken(text: descriptor.text, boundingBox: tokenBox)
            }

            return OCRTextLine(text: text, boundingBox: observation.boundingBox, tokens: tokens)
        }

        return normalize(lines)
    }

    static func tokenDescriptors(in text: String) -> [OCRTokenDescriptor] {
        var descriptors: [OCRTokenDescriptor] = []
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character.isWhitespace {
                index = text.index(after: index)
                continue
            }

            let start = index
            let currentKind = tokenKind(for: character)
            index = text.index(after: index)

            switch currentKind {
            case .word:
                while index < text.endIndex, tokenKind(for: text[index]) == .word {
                    index = text.index(after: index)
                }
            case .singleCharacter:
                break
            }

            descriptors.append(
                OCRTokenDescriptor(
                    text: String(text[start..<index]),
                    range: start..<index
                )
            )
        }

        return descriptors
    }

    private static func tokenKind(for character: Character) -> TokenKind {
        if character.unicodeScalars.allSatisfy(\.isASCIIWordLike) {
            return .word
        }

        return .singleCharacter
    }

    private enum TokenKind {
        case word
        case singleCharacter
    }

    func recognizeStrings(in image: CGImage) async throws -> [String] {
        let result = try await recognizeLayout(in: image)
        return result.lines.map(\.text)
    }

    func recognizeLayout(in image: CGImage) async throws -> OCRLayoutResult {
        try await withCheckedThrowingContinuation { continuation in
            let performRecognition = self.performRecognition
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let primaryResult = try? performRecognition(image, .primary)
                    let fallbackResult = try? performRecognition(image, .fallback)
                    let bestLines = Self.normalize(
                        Self.chooseBestResult(primary: primaryResult ?? [], fallback: fallbackResult ?? [])
                    )

                    guard !bestLines.isEmpty else {
                        continuation.resume(throwing: OCRServiceError.noTextRecognized)
                        return
                    }

                    continuation.resume(returning: OCRLayoutResult(lines: bestLines))
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

private extension Character {
    var isWhitespace: Bool {
        unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains)
    }
}

private extension UnicodeScalar {
    var isASCIIWordLike: Bool {
        switch value {
        case 48...57, 65...90, 97...122, 39, 45, 95:
            return true
        default:
            return false
        }
    }
}
