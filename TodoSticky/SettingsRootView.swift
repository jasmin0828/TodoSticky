import SwiftUI

struct SettingsRootView: View {
    let todoStore: TodoStore
    @Environment(AppLanguageController.self) private var languageController
    @Environment(LaunchAtLoginController.self) private var launchAtLoginController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var languageController = languageController
        @Bindable var launchAtLoginController = launchAtLoginController

        Form {
            Section("settings.general") {
                Picker("settings.language.label", selection: $languageController.language) {
                    Text("settings.language.system")
                        .tag(AppLanguage.system)
                    Text("settings.language.simplifiedChinese")
                        .tag(AppLanguage.simplifiedChinese)
                    Text("settings.language.english")
                        .tag(AppLanguage.english)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(
                        "settings.launchAtLogin",
                        isOn: $launchAtLoginController.isEnabled
                    )
                    .disabled(launchAtLoginController.isToggleDisabled)

                    if let feedback = launchAtLoginController.feedback {
                        Text(LocalizedStringKey(feedback.localizationKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section("settings.appearance") {
                LabeledContent("settings.color.label") {
                    SettingsColorControl(selectedColor: todoStore.selectedColor) {
                        todoStore.selectColor($0)
                    }
                }
            }

            Section("settings.about") {
                LabeledContent("settings.version") {
                    Text(AppBuildInfo.version)
                        .textSelection(.enabled)
                }

                LabeledContent("settings.build") {
                    Text(AppBuildInfo.build)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .navigationTitle("settings.title")
        .environment(\.locale, languageController.locale)
        .onAppear {
            launchAtLoginController.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            launchAtLoginController.refresh()
        }
    }
}
