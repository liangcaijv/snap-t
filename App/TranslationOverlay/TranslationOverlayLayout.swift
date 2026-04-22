import AppKit

struct TranslatedTextPlacement: Equatable {
    let text: String
    let rect: CGRect
}

enum TranslationOverlayLayout {
    static let minimumSize = CGSize(width: 220, height: 120)
    private static let maximumWidth: CGFloat = 520
    private static let horizontalPadding: CGFloat = 32
    private static let verticalChromeHeight: CGFloat = 58

    static func initialFrame(for anchorRect: CGRect, within visibleFrame: CGRect? = nil) -> CGRect {
        frame(for: anchorRect, state: .loading, within: visibleFrame)
    }

    static func frame(
        for anchorRect: CGRect,
        state: TranslationOverlayState,
        within constrainedVisibleFrame: CGRect? = nil
    ) -> CGRect {
        if case .translatedScreenshot = state {
            let size = CGSize(
                width: max(anchorRect.width, minimumSize.width),
                height: max(anchorRect.height, minimumSize.height)
            )
            return clampedFrame(
                origin: CGPoint(x: anchorRect.minX, y: anchorRect.minY),
                size: size,
                visibleFrame: constrainedVisibleFrame ?? visibleFrame(containing: anchorRect)
            )
        }

        let measuredWidth = measuredWidth(for: state)
        let measuredHeight = measuredHeight(for: state, width: measuredWidth)
        let size = CGSize(
            width: max(anchorRect.width, max(minimumSize.width, measuredWidth)),
            height: max(anchorRect.height, max(minimumSize.height, measuredHeight))
        )

        return clampedFrame(
            origin: CGPoint(x: anchorRect.minX, y: anchorRect.minY),
            size: size,
            visibleFrame: constrainedVisibleFrame ?? visibleFrame(containing: anchorRect)
        )
    }

    static func updatedFrame(
        from currentFrame: CGRect,
        state: TranslationOverlayState,
        within constrainedVisibleFrame: CGRect? = nil
    ) -> CGRect {
        if case .translatedScreenshot = state {
            return clampedFrame(
                origin: currentFrame.origin,
                size: currentFrame.size,
                visibleFrame: constrainedVisibleFrame ?? visibleFrame(containing: currentFrame)
            )
        }

        let measuredWidth = measuredWidth(for: state)
        let measuredHeight = measuredHeight(for: state, width: measuredWidth)
        let size = CGSize(
            width: max(minimumSize.width, measuredWidth),
            height: max(minimumSize.height, measuredHeight)
        )

        return clampedFrame(
            origin: currentFrame.origin,
            size: size,
            visibleFrame: constrainedVisibleFrame ?? visibleFrame(containing: currentFrame)
        )
    }

    private static func measuredWidth(for state: TranslationOverlayState) -> CGFloat {
        let textWidth = (state.layoutMessage as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 16, weight: .medium)]
        ).width + horizontalPadding
        return min(max(textWidth, minimumSize.width), maximumWidth)
    }

    private static func measuredHeight(for state: TranslationOverlayState, width: CGFloat) -> CGFloat {
        let textBounds = (state.layoutMessage as NSString).boundingRect(
            with: CGSize(width: width - horizontalPadding, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 16, weight: .medium)],
            context: nil
        )
        return ceil(textBounds.height) + verticalChromeHeight
    }

    private static func clampedFrame(origin: CGPoint, size: CGSize, visibleFrame: CGRect?) -> CGRect {
        guard let visibleFrame else {
            return CGRect(origin: origin, size: size)
        }

        let fittedSize = CGSize(
            width: min(size.width, visibleFrame.width),
            height: min(size.height, visibleFrame.height)
        )
        let clampedX = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - fittedSize.width)
        let clampedY = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - fittedSize.height)
        return CGRect(origin: CGPoint(x: clampedX, y: clampedY), size: fittedSize)
    }

    private static func visibleFrame(containing anchorRect: CGRect) -> CGRect? {
        NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchorRect) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
    }
}

enum TranslatedScreenshotLayout {
    static func imageRect(for normalizedBoundingBox: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: (normalizedBoundingBox.minX * imageSize.width).rounded(),
            y: ((1 - normalizedBoundingBox.maxY) * imageSize.height).rounded(),
            width: (normalizedBoundingBox.width * imageSize.width).rounded(),
            height: (normalizedBoundingBox.height * imageSize.height).rounded()
        )
    }

    static func linePlacement(
        for line: TranslatedTextLine,
        imageSize: CGSize
    ) -> TranslatedTextPlacement {
        TranslatedTextPlacement(
            text: line.translatedText,
            rect: imageRect(for: line.boundingBox, imageSize: imageSize)
        )
    }

    static func coverRect(for textRect: CGRect, padding: CGFloat = 4) -> CGRect {
        textRect.insetBy(dx: -padding, dy: -padding / 2).integral
    }

    static func fittedFontSize(
        for text: String,
        in rect: CGRect,
        minimum: CGFloat = 8,
        maximum: CGFloat? = nil
    ) -> CGFloat {
        let upperBound = maximum ?? max(min(rect.height * 0.82, 28), minimum)
        var fontSize = upperBound

        while fontSize > minimum {
            let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )

            if ceil(bounds.height) <= rect.height {
                return fontSize
            }

            fontSize -= 1
        }

        return minimum
    }

    static func placements(for text: String, sourceTokenRects: [CGRect]) -> [TranslatedTextPlacement] {
        let units = renderUnits(for: text)
        guard !units.isEmpty else {
            return []
        }

        let slotRects = slots(for: sourceTokenRects, count: units.count)
        return zip(units, slotRects).map { unit, rect in
            TranslatedTextPlacement(text: unit, rect: rect)
        }
    }

    private static func renderUnits(for text: String) -> [String] {
        let words = text
            .split(whereSeparator: { $0.unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains) })
            .map(String.init)
            .filter { !$0.isEmpty }
        if words.count > 1 {
            return words
        }

        return text
            .filter { !$0.unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains) }
            .map(String.init)
    }

    private static func slots(for sourceTokenRects: [CGRect], count: Int) -> [CGRect] {
        guard count > 0 else {
            return []
        }

        if sourceTokenRects.isEmpty {
            return Array(repeating: .zero, count: count)
        }

        let sortedRects = sourceTokenRects.sorted { $0.minX < $1.minX }

        if sortedRects.count == count {
            return sortedRects
        }

        if sortedRects.count > count {
            return groupedRects(sortedRects, count: count)
        }

        return subdividedRects(sortedRects, count: count)
    }

    private static func groupedRects(_ rects: [CGRect], count: Int) -> [CGRect] {
        let widths = rects.map(\.width)
        let totalWidth = widths.reduce(0, +)
        guard totalWidth > 0 else {
            return Array(rects.prefix(count))
        }

        var groups: [CGRect] = []
        var currentRects: [CGRect] = []
        var accumulatedWidth: CGFloat = 0
        var currentThreshold = totalWidth / CGFloat(count)

        for (index, rect) in rects.enumerated() {
            currentRects.append(rect)
            accumulatedWidth += rect.width

            let remainingRects = rects.count - index - 1
            let remainingGroups = count - groups.count - 1
            let shouldCloseGroup = groups.count < count - 1
                && accumulatedWidth >= currentThreshold
                && remainingRects >= remainingGroups

            if shouldCloseGroup {
                groups.append(currentRects.reduce(currentRects[0], { $0.union($1) }))
                currentRects.removeAll()
                currentThreshold = (totalWidth - widths.prefix(index + 1).reduce(0, +)) / CGFloat(max(remainingGroups, 1))
                accumulatedWidth = 0
            }
        }

        if let first = currentRects.first {
            groups.append(currentRects.reduce(first, { $0.union($1) }))
        }

        return groups
    }

    private static func subdividedRects(_ rects: [CGRect], count: Int) -> [CGRect] {
        let widths = rects.map { max($0.width, 1) }
        let totalWidth = widths.reduce(0, +)
        let extraSlots = count - rects.count

        var slotCounts = Array(repeating: 1, count: rects.count)
        if extraSlots > 0, totalWidth > 0 {
            let rawExtras = widths.map { $0 / totalWidth * CGFloat(extraSlots) }
            var assignedExtras = rawExtras.map { Int(floor($0)) }
            var remaining = extraSlots - assignedExtras.reduce(0, +)
            let rankedIndices = rawExtras.enumerated()
                .sorted { ($0.element - floor($0.element)) > ($1.element - floor($1.element)) }
                .map(\.offset)
            var cursor = 0
            while remaining > 0, !rankedIndices.isEmpty {
                assignedExtras[rankedIndices[cursor % rankedIndices.count]] += 1
                remaining -= 1
                cursor += 1
            }
            for index in slotCounts.indices {
                slotCounts[index] += assignedExtras[index]
            }
        }

        var slots: [CGRect] = []
        for (rect, slotCount) in zip(rects, slotCounts) {
            let width = rect.width / CGFloat(slotCount)
            for index in 0..<slotCount {
                slots.append(
                    CGRect(
                        x: rect.minX + CGFloat(index) * width,
                        y: rect.minY,
                        width: width,
                        height: rect.height
                    )
                )
            }
        }
        return slots
    }
}

private extension TranslationOverlayState {
    var layoutMessage: String {
        switch self {
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
