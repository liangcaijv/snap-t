import CoreGraphics

struct CapturedImageDebugStore: CapturedImageDebugStoring {
    func persist(_ image: CGImage) -> String? {
        nil
    }
}
