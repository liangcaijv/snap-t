import AppKit
import SwiftUI

protocol TranslationOverlayClickMonitoring {
    func installGlobalMonitor(handler: @escaping (CGPoint) -> Void) -> Any?
    func installLocalMonitor(handler: @escaping (CGPoint) -> Void) -> Any?
    func removeMonitor(_ monitor: Any)
}

struct NSEventTranslationOverlayClickMonitor: TranslationOverlayClickMonitoring {
    func installGlobalMonitor(handler: @escaping (CGPoint) -> Void) -> Any? {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            handler(NSEvent.mouseLocation)
        }
    }

    func installLocalMonitor(handler: @escaping (CGPoint) -> Void) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            handler(NSEvent.mouseLocation)
            return event
        }
    }

    func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

@MainActor
final class TranslationOverlayController {
    private let clickMonitor: TranslationOverlayClickMonitoring
    private var window: TranslationOverlayWindow?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var anchorRect: CGRect?

    private(set) var state: TranslationOverlayState?

    init(clickMonitor: TranslationOverlayClickMonitoring = NSEventTranslationOverlayClickMonitor()) {
        self.clickMonitor = clickMonitor
    }

    var isPresented: Bool {
        window != nil
    }

    var currentFrame: CGRect? {
        window?.frame
    }

    func presentLoading(anchoredTo anchorRect: CGRect) {
        present(state: .loading, anchoredTo: anchorRect)
    }

    func showTranslation(_ text: String) {
        update(state: .translated(text))
    }

    func showTranslatedScreenshot(_ result: TranslatedScreenshotResult) {
        update(state: .translatedScreenshot(result))
    }

    func showFailure(_ message: String) {
        update(state: .failure(message))
    }

    func showNoText() {
        update(state: .noText)
    }

    func dismiss() {
        if let globalMonitor {
            clickMonitor.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            clickMonitor.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        state = nil
        anchorRect = nil
    }

    func setFrameOriginForTesting(_ point: CGPoint) {
        window?.setFrameOrigin(point)
    }

    private func present(state: TranslationOverlayState, anchoredTo anchorRect: CGRect) {
        dismiss()

        let window = TranslationOverlayWindow(
            contentRect: TranslationOverlayLayout.initialFrame(for: anchorRect),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.contentView = NSHostingView(rootView: TranslationOverlayView(state: state))
        window.makeKeyAndOrderFront(nil)
        self.window = window
        self.anchorRect = anchorRect
        self.state = state

        globalMonitor = clickMonitor.installGlobalMonitor { [weak self] point in
            self?.handleClick(at: point)
        }
        localMonitor = clickMonitor.installLocalMonitor { [weak self] point in
            self?.handleClick(at: point)
        }
    }

    private func update(state: TranslationOverlayState) {
        guard let window else {
            return
        }

        window.setFrame(
            TranslationOverlayLayout.updatedFrame(from: window.frame, state: state),
            display: true
        )
        window.contentView = NSHostingView(rootView: TranslationOverlayView(state: state))
        self.state = state
    }

    private func handleClick(at point: CGPoint) {
        guard let window else {
            return
        }

        guard !window.frame.contains(point) else {
            return
        }

        dismiss()
    }
}

private final class TranslationOverlayWindow: NSWindow {
    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { true }
}
