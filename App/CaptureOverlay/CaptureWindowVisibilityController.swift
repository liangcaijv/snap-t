import AppKit

@MainActor
final class CaptureWindowVisibilityController {
    private struct TrackedWindow {
        let window: NSWindow
        let shouldRestore: Bool
    }

    private var trackedWindows: [TrackedWindow] = []

    func hideTrackedWindows(in windows: [NSWindow]) {
        trackedWindows = windows.compactMap { window in
            guard shouldTrack(window) else {
                return nil
            }

            window.orderOut(nil)
            return TrackedWindow(window: window, shouldRestore: shouldRestore(window))
        }
    }

    func restoreTrackedWindows() {
        for trackedWindow in trackedWindows where trackedWindow.shouldRestore {
            trackedWindow.window.orderFrontRegardless()
        }
        trackedWindows.removeAll()
    }

    func shouldTrack(_ window: NSWindow) -> Bool {
        !window.styleMask.isEmpty && !(window is NSPanel)
    }

    private func shouldRestore(_ window: NSWindow) -> Bool {
        shouldTrack(window) && window.identifier != .settingsWindow
    }
}
