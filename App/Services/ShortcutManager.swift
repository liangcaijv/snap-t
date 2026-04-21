import AppKit
import Carbon
import Foundation

struct ScreenshotShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiersRawValue: UInt

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = UInt32(keyCode)
        self.modifiersRawValue = modifiers.intersection([.command, .option, .control, .shift]).rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    static let `default` = ScreenshotShortcut(keyCode: 18, modifiers: [.control, .option])

    var displayString: String {
        let modifierGlyphs = [
            modifiers.contains(.control) ? "⌃" : nil,
            modifiers.contains(.option) ? "⌥" : nil,
            modifiers.contains(.shift) ? "⇧" : nil,
            modifiers.contains(.command) ? "⌘" : nil,
        ]
        .compactMap { $0 }
        .joined()

        return modifierGlyphs + keyDisplay
    }

    private var keyDisplay: String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 49: return "Space"
        default: return "Key \(keyCode)"
        }
    }
}

enum ShortcutCodec {
    static func encode(_ shortcut: ScreenshotShortcut) throws -> Data {
        try JSONEncoder().encode(shortcut)
    }

    static func decode(_ data: Data) throws -> ScreenshotShortcut {
        try JSONDecoder().decode(ScreenshotShortcut.self, from: data)
    }
}

protocol HotKeyRegistering {
    func register(shortcut: ScreenshotShortcut, handler: @escaping () -> Void) throws -> AnyObject
    func unregister(handle: AnyObject)
}

enum ShortcutManagerError: Error {
    case registrationFailed(OSStatus)
}

@MainActor
final class ShortcutManager {
    private let registrar: HotKeyRegistering
    private var handle: AnyObject?

    init(registrar: HotKeyRegistering = CarbonHotKeyRegistrar()) {
        self.registrar = registrar
    }

    func register(shortcut: ScreenshotShortcut, handler: @escaping () -> Void) throws {
        if let handle {
            registrar.unregister(handle: handle)
        }
        handle = try registrar.register(shortcut: shortcut, handler: handler)
    }
}

final class CarbonHotKeyRegistrar: HotKeyRegistering {
    private static let signature = OSType(0x53545447) // STTG
    nonisolated(unsafe) static var nextID: UInt32 = 1
    nonisolated(unsafe) static var handlers: [UInt32: () -> Void] = [:]
    nonisolated(unsafe) static var handlerInstalled = false

    func register(shortcut: ScreenshotShortcut, handler: @escaping () -> Void) throws -> AnyObject {
        try Self.installEventHandlerIfNeeded()

        var hotKeyRef: EventHotKeyRef?
        let identifier = Self.nextID
        Self.nextID += 1

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers(for: shortcut.modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, let hotKeyRef else {
            throw ShortcutManagerError.registrationFailed(status)
        }

        Self.handlers[identifier] = handler
        return CarbonHotKeyHandle(id: identifier, reference: hotKeyRef)
    }

    func unregister(handle: AnyObject) {
        guard let handle = handle as? CarbonHotKeyHandle else {
            return
        }

        UnregisterEventHotKey(handle.reference)
        Self.handlers.removeValue(forKey: handle.id)
    }

    private static func installEventHandlerIfNeeded() throws {
        guard !handlerInstalled else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            carbonHotKeyEventHandler,
            1,
            &eventSpec,
            nil,
            nil
        )
        guard status == noErr else {
            throw ShortcutManagerError.registrationFailed(status)
        }

        handlerInstalled = true
    }

    private func carbonModifiers(for modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

private final class CarbonHotKeyHandle: NSObject {
    let id: UInt32
    let reference: EventHotKeyRef

    init(id: UInt32, reference: EventHotKeyRef) {
        self.id = id
        self.reference = reference
    }
}

private func carbonHotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let result = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if result == noErr, let handler = CarbonHotKeyRegistrar.handlers[hotKeyID.id] {
        handler()
    }

    return noErr
}
