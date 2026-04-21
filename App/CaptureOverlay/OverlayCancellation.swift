import AppKit

enum OverlayCancellation {
    static func shouldCancel(keyCode: UInt16) -> Bool {
        keyCode == 53
    }
}
