import SwiftUI

enum TranslationOverlayState: Equatable {
    case loading
    case translated(String)
    case translatedScreenshot(TranslatedScreenshotResult)
    case failure(String)
    case noText
}

struct TranslationOverlayView: View {
    let state: TranslationOverlayState

    var body: some View {
        Group {
            switch state {
            case let .translatedScreenshot(result):
                TranslatedScreenshotOverlayView(result: result)
            default:
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.vertical, showsIndicators: true) {
                        Text(message)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                )
            }
        }
    }

    private var title: String {
        switch state {
        case .loading:
            return "Translating"
        case .translated:
            return "Translation"
        case .translatedScreenshot:
            return "Translation"
        case .failure:
            return "Translation Failed"
        case .noText:
            return "No Text"
        }
    }

    private var message: String {
        switch state {
        case .loading:
            return "Translating..."
        case let .translated(text):
            return text
        case let .translatedScreenshot(result):
            return result.lines.map(\.translatedText).joined(separator: "\n")
        case let .failure(message):
            return message
        case .noText:
            return "No text recognized."
        }
    }
}

private struct TranslatedScreenshotOverlayView: View {
    let result: TranslatedScreenshotResult

    var body: some View {
        GeometryReader { proxy in
            let fittedFrame = aspectFitFrame(for: result.imageSize, in: proxy.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)

                Image(decorative: result.image, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fittedFrame.width, height: fittedFrame.height)
                    .position(x: fittedFrame.midX, y: fittedFrame.midY)

                ForEach(Array(result.lines.enumerated()), id: \.offset) { _, line in
                    let placement = TranslatedScreenshotLayout.linePlacement(
                        for: line,
                        imageSize: result.imageSize
                    )
                    let displayRect = scaledRect(
                        placement.rect,
                        imageSize: result.imageSize,
                        fittedFrame: fittedFrame
                    )
                    let coverRect = TranslatedScreenshotLayout.coverRect(
                        for: displayRect,
                        padding: max(2, min(displayRect.height * 0.18, 6))
                    )
                    let fontSize = TranslatedScreenshotLayout.fittedFontSize(
                        for: placement.text,
                        in: displayRect
                    )
                    let backgroundColor = sampledBackgroundColor(
                        around: placement.rect
                    ) ?? Color.white.opacity(0.96)

                    RoundedRectangle(cornerRadius: max(2, coverRect.height * 0.12), style: .continuous)
                        .fill(backgroundColor)
                        .frame(width: coverRect.width, height: coverRect.height)
                        .position(x: coverRect.midX, y: coverRect.midY)

                    Text(placement.text)
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(width: displayRect.width, height: displayRect.height, alignment: .topLeading)
                        .position(x: displayRect.midX, y: displayRect.midY)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func aspectFitFrame(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func scaledRect(_ rect: CGRect, imageSize: CGSize, fittedFrame: CGRect) -> CGRect {
        let scaleX = fittedFrame.width / imageSize.width
        let scaleY = fittedFrame.height / imageSize.height
        return CGRect(
            x: fittedFrame.minX + rect.minX * scaleX,
            y: fittedFrame.minY + rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }

    private func sampledBackgroundColor(around imageRect: CGRect) -> Color? {
        result.image.sampledBackgroundColor(around: imageRect).map(Color.init(nsColor:))
    }
}

private extension CGImage {
    func sampledBackgroundColor(around rect: CGRect) -> NSColor? {
        let points = [
            CGPoint(x: rect.minX + 1, y: rect.minY + 1),
            CGPoint(x: rect.maxX - 2, y: rect.minY + 1),
            CGPoint(x: rect.minX + 1, y: rect.maxY - 2),
            CGPoint(x: rect.maxX - 2, y: rect.maxY - 2),
        ]
        let samples = points.compactMap { color(at: $0) }
        guard !samples.isEmpty else {
            return nil
        }

        let red = samples.map(\.redComponent).reduce(0, +) / CGFloat(samples.count)
        let green = samples.map(\.greenComponent).reduce(0, +) / CGFloat(samples.count)
        let blue = samples.map(\.blueComponent).reduce(0, +) / CGFloat(samples.count)
        let alpha = samples.map(\.alphaComponent).reduce(0, +) / CGFloat(samples.count)
        return NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }

    func color(at point: CGPoint) -> NSColor? {
        guard
            let provider = dataProvider,
            let data = provider.data,
            let bytes = CFDataGetBytePtr(data)
        else {
            return nil
        }

        let x = min(max(Int(point.x.rounded(.down)), 0), width - 1)
        let y = min(max(Int(point.y.rounded(.down)), 0), height - 1)
        let bitsPerPixel = bitsPerPixel / 8
        guard bitsPerPixel >= 4 else {
            return nil
        }

        let offset = y * bytesPerRow + x * bitsPerPixel
        let red = CGFloat(bytes[offset]) / 255
        let green = CGFloat(bytes[offset + 1]) / 255
        let blue = CGFloat(bytes[offset + 2]) / 255
        let alpha = CGFloat(bytes[offset + 3]) / 255
        return NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }
}
