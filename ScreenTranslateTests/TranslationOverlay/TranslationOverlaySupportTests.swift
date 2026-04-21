import AppKit
import XCTest
@testable import ScreenTranslate

@MainActor
final class TranslationOverlaySupportTests: XCTestCase {
    func test展示浮层时会安装点击监视器() {
        let monitor = RecordingClickMonitor()
        let controller = TranslationOverlayController(clickMonitor: monitor)
        defer { controller.dismiss() }

        controller.presentLoading(anchoredTo: CGRect(x: 100, y: 200, width: 80, height: 40))

        XCTAssertTrue(controller.isPresented)
        XCTAssertEqual(monitor.installedMonitorCount, 2)
    }

    func testdismiss会移除已安装的点击监视器() {
        let monitor = RecordingClickMonitor()
        let controller = TranslationOverlayController(clickMonitor: monitor)
        controller.presentLoading(anchoredTo: CGRect(x: 100, y: 200, width: 80, height: 40))

        controller.dismiss()

        XCTAssertFalse(controller.isPresented)
        XCTAssertEqual(monitor.removedMonitorCount, 2)
    }

    func test点击浮层外会自动关闭() {
        let monitor = RecordingClickMonitor()
        let controller = TranslationOverlayController(clickMonitor: monitor)
        defer { controller.dismiss() }
        controller.presentLoading(anchoredTo: CGRect(x: 100, y: 200, width: 220, height: 120))

        monitor.fireGlobalClick(at: CGPoint(x: 20, y: 20))

        XCTAssertFalse(controller.isPresented)
    }

    func test点击浮层内不会关闭() {
        let monitor = RecordingClickMonitor()
        let controller = TranslationOverlayController(clickMonitor: monitor)
        defer { controller.dismiss() }
        controller.presentLoading(anchoredTo: CGRect(x: 100, y: 200, width: 220, height: 120))

        monitor.fireLocalClick(at: CGPoint(x: 140, y: 240))

        XCTAssertTrue(controller.isPresented)
    }

    func test更新为翻译结果时会刷新状态() {
        let monitor = RecordingClickMonitor()
        let controller = TranslationOverlayController(clickMonitor: monitor)
        defer { controller.dismiss() }
        controller.presentLoading(anchoredTo: CGRect(x: 100, y: 200, width: 80, height: 40))
        let initialFrame = try! XCTUnwrap(controller.currentFrame)

        controller.showTranslation("A much longer translated paragraph that should expand the overlay frame.")

        XCTAssertEqual(
            controller.state,
            .translated("A much longer translated paragraph that should expand the overlay frame.")
        )
        let updatedFrame = try! XCTUnwrap(controller.currentFrame)
        XCTAssertGreaterThan(updatedFrame.width, initialFrame.width)
    }

    func test更新状态时会保留用户拖动后的位置() {
        let monitor = RecordingClickMonitor()
        let controller = TranslationOverlayController(clickMonitor: monitor)
        defer { controller.dismiss() }
        controller.presentLoading(anchoredTo: CGRect(x: 100, y: 200, width: 80, height: 40))
        controller.setFrameOriginForTesting(CGPoint(x: 260, y: 260))

        controller.showTranslation("A much longer translated paragraph that should expand the overlay frame.")

        let updatedFrame = try! XCTUnwrap(controller.currentFrame)
        XCTAssertEqual(updatedFrame.origin.x, 260)
        XCTAssertEqual(updatedFrame.origin.y, 260)
    }

    func test更新为失败和无文本时会刷新状态() {
        let monitor = RecordingClickMonitor()
        let controller = TranslationOverlayController(clickMonitor: monitor)
        defer { controller.dismiss() }
        controller.presentLoading(anchoredTo: CGRect(x: 100, y: 200, width: 80, height: 40))

        controller.showFailure("rate limited")
        XCTAssertEqual(controller.state, .failure("rate limited"))

        controller.showNoText()
        XCTAssertEqual(controller.state, .noText)
    }
}

private final class RecordingClickMonitor: TranslationOverlayClickMonitoring {
    private(set) var installedMonitorCount = 0
    private(set) var removedMonitorCount = 0

    private var globalHandler: ((CGPoint) -> Void)?
    private var localHandler: ((CGPoint) -> Void)?

    func installGlobalMonitor(handler: @escaping (CGPoint) -> Void) -> Any? {
        installedMonitorCount += 1
        globalHandler = handler
        return UUID()
    }

    func installLocalMonitor(handler: @escaping (CGPoint) -> Void) -> Any? {
        installedMonitorCount += 1
        localHandler = handler
        return UUID()
    }

    func removeMonitor(_ monitor: Any) {
        removedMonitorCount += 1
    }

    func fireGlobalClick(at point: CGPoint) {
        globalHandler?(point)
    }

    func fireLocalClick(at point: CGPoint) {
        localHandler?(point)
    }
}
