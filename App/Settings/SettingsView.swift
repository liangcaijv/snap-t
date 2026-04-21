import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("ScreenTranslate")
                .font(.system(size: 24, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text("DashScope API Key")
                    .font(.system(size: 13, weight: .medium))

                SecureField("Enter DashScope API key", text: $model.apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                Button(model.hasStoredAPIKey ? "Update API Key" : "Save API Key") {
                    model.saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Target Language")
                    .font(.system(size: 13, weight: .medium))

                Picker("Target Language", selection: $model.targetLanguageCode) {
                    ForEach(SupportedTranslationLanguage.all) { language in
                        Text(language.displayName).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Screenshot Shortcut")
                    .font(.system(size: 13, weight: .medium))

                ShortcutRecorder(shortcut: $model.screenshotShortcut)
            }

            Text(model.statusMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(model.hasStoredAPIKey ? .secondary : .orange)

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(SettingsWindowIdentifierView())
    }
}

private struct SettingsWindowIdentifierView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        applyIdentifier(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyIdentifier(to: nsView)
    }

    private func applyIdentifier(to view: NSView) {
        DispatchQueue.main.async {
            view.window?.identifier = .settingsWindow
        }
    }
}
