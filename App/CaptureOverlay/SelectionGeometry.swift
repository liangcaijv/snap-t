import CoreGraphics

enum SelectionGeometry {
    static let minimumSelectionLength: CGFloat = 8

    static func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    static func clamp(_ rect: CGRect, to screenFrame: CGRect) -> CGRect {
        rect.standardized.intersection(screenFrame)
    }

    static func isValidSelection(_ rect: CGRect) -> Bool {
        rect.width >= minimumSelectionLength && rect.height >= minimumSelectionLength
    }

    static func displayCaptureRect(
        forLocalSelection selection: CGRect,
        screenSize: CGSize,
        pixelSize: CGSize
    ) -> CGRect {
        let scaleX = pixelSize.width / screenSize.width
        let scaleY = pixelSize.height / screenSize.height

        return CGRect(
            x: selection.minX * scaleX,
            y: selection.minY * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        ).integral
    }
}
