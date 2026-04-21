import SwiftUI

@main
struct ScreenTranslateApp: App {
    private let translationConfigurationStore: TranslationConfigurationStore
    @StateObject private var appModel: AppModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let translationConfigurationStore = TranslationConfigurationStore()
        self.translationConfigurationStore = translationConfigurationStore
        _appModel = StateObject(
            wrappedValue: AppModel(translationConfigurationStore: translationConfigurationStore)
        )
    }

    var body: some Scene {
        MenuBarExtra("ScreenTranslate", systemImage: "text.viewfinder") {
            MenuBarContentView(
                model: appModel,
                startCapture: {
                    appDelegate.startCapture()
                }
            )
            .task {
                appDelegate.configure(translationConfigurationStore: translationConfigurationStore)
            }
        }

        Settings {
            SettingsView(model: appModel)
                .frame(minWidth: 420, minHeight: 320)
                .task {
                    appDelegate.configure(translationConfigurationStore: translationConfigurationStore)
                }
        }
    }
}

private struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings

    @ObservedObject var model: AppModel
    let startCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Button("开始截图") {
                startCapture()
            }
            .buttonStyle(.borderedProminent)

            Button("设置...") {
                SettingsPresenter(
                    activateApp: {
                        NSApp.activate(ignoringOtherApps: true)
                    },
                    openSettings: {
                        openSettings()
                    }
                )
                .present()
            }

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
    }
}

struct SettingsPresenter {
    let activateApp: () -> Void
    let openSettings: () -> Void

    func present() {
        activateApp()
        openSettings()
    }
}
