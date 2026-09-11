import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var localizer: Localizer
    let loginItem: LoginItemService
    let showPreview: () -> Void

    var body: some View {
        Form {
            Toggle(localizer.text("settings.toastEnabled"), isOn: $store.settings.toastEnabled)
            Picker(localizer.text("settings.toastPosition"), selection: $store.settings.toastPosition) {
                ForEach(ToastPosition.allCases) { position in Text(position.label).tag(position) }
            }
            Picker(localizer.text("settings.toastContent"), selection: $store.settings.toastContentMode) {
                Text(localizer.text("settings.localizedText")).tag(ToastContentMode.localizedText)
                Text(localizer.text("settings.customText")).tag(ToastContentMode.customText)
                Text(localizer.text("settings.iconOnly")).tag(ToastContentMode.iconOnly)
            }
            TextField(localizer.text("settings.customText"), text: $store.settings.customToastText)
                .disabled(store.settings.toastContentMode != .customText)
            Picker(localizer.text("settings.language"), selection: $localizer.language) {
                Text("System").tag(AppLanguage.system)
                Text("Русский").tag(AppLanguage.russian)
                Text("English").tag(AppLanguage.english)
            }
            Toggle(localizer.text("settings.launchAtLogin"), isOn: Binding(
                get: { store.settings.launchAtLogin },
                set: { newValue in
                    store.settings.launchAtLogin = newValue
                    try? loginItem.setEnabled(newValue)
                }
            ))
            Button(localizer.text("menu.testToast"), action: showPreview)
        }
        .padding(20)
        .frame(width: 430)
    }
}
