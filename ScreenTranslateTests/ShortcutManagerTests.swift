import AppKit
import XCTest
@testable import ScreenTranslate

final class ShortcutManagerTests: XCTestCase {
    func test快捷键可序列化和恢复() throws {
        let shortcut = ScreenshotShortcut(
            keyCode: 18,
            modifiers: [.control, .option]
        )

        let data = try ShortcutCodec.encode(shortcut)
        let decoded = try ShortcutCodec.decode(data)

        XCTAssertEqual(decoded, shortcut)
    }

    @MainActor
    func test注册新快捷键时会替换旧注册() throws {
        let registrar = RecordingHotKeyRegistrar()
        let manager = ShortcutManager(registrar: registrar)
        let first = ScreenshotShortcut(keyCode: 18, modifiers: [.control, .option])
        let second = ScreenshotShortcut(keyCode: 19, modifiers: [.command, .shift])

        try manager.register(shortcut: first) {}
        try manager.register(shortcut: second) {}

        XCTAssertEqual(registrar.registeredShortcuts, [first, second])
        XCTAssertEqual(registrar.unregisteredHandleIDs, [1])
    }
}

private final class RecordingHotKeyRegistrar: HotKeyRegistering {
    private(set) var registeredShortcuts: [ScreenshotShortcut] = []
    private(set) var unregisteredHandleIDs: [Int] = []
    private var nextID = 0

    func register(shortcut: ScreenshotShortcut, handler: @escaping () -> Void) throws -> AnyObject {
        nextID += 1
        registeredShortcuts.append(shortcut)
        return RecordingHotKeyHandle(id: nextID)
    }

    func unregister(handle: AnyObject) {
        guard let handle = handle as? RecordingHotKeyHandle else {
            return
        }
        unregisteredHandleIDs.append(handle.id)
    }
}

private final class RecordingHotKeyHandle: NSObject {
    let id: Int

    init(id: Int) {
        self.id = id
    }
}
