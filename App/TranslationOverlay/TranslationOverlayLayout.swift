import AppKit

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

private extension TranslationOverlayState {
    var layoutMessage: String {
        switch self {
        case .loading:
            return "Translating..."
        case let .translated(text):
            return text
        case let .failure(message):
            return message
        case .noText:
            return "No text recognized."
        }
    }
}
