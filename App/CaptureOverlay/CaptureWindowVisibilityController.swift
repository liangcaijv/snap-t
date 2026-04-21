import AppKit

@MainActor
final class CaptureWindowVisibilityController {
    private var trackedWindows: [NSWindow] = []

    func hideTrackedWindows(in windows: [NSWindow]) {
        trackedWindows = windows.filter(shouldTrack)
        for window in trackedWindows {
            window.orderOut(nil)
        }
    }

    func restoreTrackedWindows() {
        for window in trackedWindows {
            window.orderFrontRegardless()
        }
        trackedWindows.removeAll()
    }

    func shouldTrack(_ window: NSWindow) -> Bool {
        !window.styleMask.isEmpty && !(window is NSPanel)
    }
}
