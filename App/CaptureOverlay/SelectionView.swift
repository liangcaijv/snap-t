import SwiftUI

struct SelectionView: View {
    let onSelectionFinished: (CGRect) -> Void
    let onCancelled: () -> Void

    @State private var dragStartPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    private var selectionRect: CGRect? {
        guard let dragStartPoint, let currentPoint else {
            return nil
        }
        return SelectionGeometry.normalizedRect(from: dragStartPoint, to: currentPoint)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                selectionMask(in: proxy.size)

                if let selectionRect {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.95), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.clear)
                                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
                        )
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStartPoint == nil {
                            dragStartPoint = value.startLocation
                        }
                        currentPoint = value.location
                    }
                    .onEnded { value in
                        let rect = SelectionGeometry.normalizedRect(from: value.startLocation, to: value.location)
                        dragStartPoint = nil
                        currentPoint = nil

                        guard SelectionGeometry.isValidSelection(rect) else {
                            onCancelled()
                            return
                        }

                        onSelectionFinished(rect)
                    }
            )
        }
        .background(.clear)
        .onAppear {
            NSCursor.crosshair.push()
        }
        .onDisappear {
            NSCursor.pop()
        }
    }

    @ViewBuilder
    private func selectionMask(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var path = Path(CGRect(origin: .zero, size: canvasSize))
            if let selectionRect {
                path.addRoundedRect(in: selectionRect, cornerSize: CGSize(width: 14, height: 14))
            }
            context.fill(
                path,
                with: .color(.black.opacity(0.28)),
                style: FillStyle(eoFill: selectionRect != nil)
            )
        }
        .frame(width: size.width, height: size.height)
    }
}
