import SwiftUI

struct SettingsRootView: View {
    let todoStore: TodoStore
    @Environment(AppLanguageController.self) private var languageController

    var body: some View {
        @Bindable var languageController = languageController

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
    }
}
