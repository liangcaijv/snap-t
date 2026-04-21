import AppKit
import SwiftUI

struct ShortcutRecorder: View {
    @Binding var shortcut: ScreenshotShortcut

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? "Press shortcut…" : shortcut.displayString) {
            startRecording()
        }
        .buttonStyle(.bordered)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            shortcut = ScreenshotShortcut(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags
            )
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}
