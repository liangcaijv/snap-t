import AppKit
import SwiftUI

enum ScreenCaptureAuthorization {
    static func isAuthorized(
        preflight: () -> Bool = { CGPreflightScreenCaptureAccess() },
        request: () -> Bool = { CGRequestScreenCaptureAccess() }
    ) -> Bool {
        preflight() || request()
    }
}

@MainActor
final class OverlayWindowController: ScreenRegionCapturing {
    private var windows: [NSWindow] = []
    private var completion: ((Result<CapturedRegion, CaptureError>) -> Void)?
    private var eventMonitor: Any?
    private(set) var lastCaptureRect: CGRect?

    func present(completion: @escaping (Result<CapturedRegion, CaptureError>) -> Void) {
        dismiss()
        installEventMonitor()

        self.completion = completion
        lastCaptureRect = nil
        windows = NSScreen.screens.map(makeWindow(for:))

        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func dismiss() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let selectionView = SelectionView(
            onSelectionFinished: { [weak self] rect in
                self?.captureSelection(rect, on: screen)
            },
            onCancelled: { [weak self] in
                self?.dismiss()
                self?.finish(with: .failure(.cancelled))
            }
        )

        let window = CaptureOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = CaptureOverlayHostingView(rootView: selectionView)
        return window
    }

    private func captureSelection(_ localSelection: CGRect, on screen: NSScreen) {
        let clampedLocalSelection = SelectionGeometry.clamp(
            localSelection,
            to: CGRect(origin: .zero, size: screen.frame.size)
        )

        guard SelectionGeometry.isValidSelection(clampedLocalSelection) else {
            dismiss()
            lastCaptureRect = nil
            finish(with: .failure(.cancelled))
            return
        }

        guard ScreenCaptureAuthorization.isAuthorized() else {
            dismiss()
            lastCaptureRect = nil
            finish(with: .failure(.permissionDenied))
            return
        }

        lastCaptureRect = clampedLocalSelection.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)

        dismiss()

        guard let displayID = screen.displayID else {
            finish(with: .failure(.captureFailed))
            return
        }

        let pixelSize = CGSize(
            width: CGFloat(CGDisplayPixelsWide(displayID)),
            height: CGFloat(CGDisplayPixelsHigh(displayID))
        )
        let captureRect = SelectionGeometry.displayCaptureRect(
            forLocalSelection: clampedLocalSelection,
            screenSize: screen.frame.size,
            pixelSize: pixelSize
        )

        let image = CGDisplayCreateImage(displayID, rect: captureRect)
        if let image {
            finish(with: .success(CapturedRegion(image: image)))
            return
        }

        let error: CaptureError = CGPreflightScreenCaptureAccess() ? .captureFailed : .permissionDenied
        finish(with: .failure(error))
    }

    private func finish(with result: Result<CapturedRegion, CaptureError>) {
        let completion = self.completion
        self.completion = nil
        completion?(result)
    }

    private func installEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard OverlayCancellation.shouldCancel(keyCode: event.keyCode) else {
                return event
            }

            self?.dismiss()
            self?.finish(with: .failure(.cancelled))
            return nil
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

private final class CaptureOverlayWindow: NSWindow {
    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { true }
}

private final class CaptureOverlayHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
