import AppKit
import XCTest
@testable import ScreenTranslate

@MainActor
final class CaptureOverlaySupportTests: XCTestCase {
    private let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("settings-window")

    func testEscape键会触发取消() {
        XCTAssertTrue(OverlayCancellation.shouldCancel(keyCode: 53))
        XCTAssertFalse(OverlayCancellation.shouldCancel(keyCode: 0))
    }

    func test截图蒙层内容视图接受首次点击() {
        let controller = OverlayWindowController()
        controller.present { _ in }

        let overlayWindows = NSApp.windows.filter { $0.styleMask == [.borderless] }
        defer {
            overlayWindows.forEach { window in
                window.orderOut(nil)
                window.close()
            }
        }

        XCTAssertFalse(overlayWindows.isEmpty)
        XCTAssertTrue(
            overlayWindows.allSatisfy { $0.contentView?.acceptsFirstMouse(for: nil) == true }
        )
    }

    func test窗口可见性控制器不会追踪Borderless窗口() {
        let controller = CaptureWindowVisibilityController()
        let normalWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let borderlessWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(controller.shouldTrack(normalWindow))
        XCTAssertFalse(controller.shouldTrack(borderlessWindow))
    }

    func test设置窗口在截图后不会自动恢复() {
        let controller = CaptureWindowVisibilityController()
        let settingsWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        settingsWindow.identifier = settingsWindowIdentifier
        settingsWindow.orderFrontRegardless()

        controller.hideTrackedWindows(in: [settingsWindow])
        XCTAssertFalse(settingsWindow.isVisible)

        controller.restoreTrackedWindows()

        XCTAssertFalse(settingsWindow.isVisible)
    }

    func test普通窗口在截图后仍会恢复() {
        let controller = CaptureWindowVisibilityController()
        let normalWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        normalWindow.orderFrontRegardless()

        controller.hideTrackedWindows(in: [normalWindow])
        XCTAssertFalse(normalWindow.isVisible)

        controller.restoreTrackedWindows()

        XCTAssertTrue(normalWindow.isVisible)
    }
}
