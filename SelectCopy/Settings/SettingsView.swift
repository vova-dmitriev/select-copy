import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var localizer: Localizer
    let loginItem: LoginItemService
    let showPreview: () -> Void

    var body: some View {
        Form {
            Toggle(self.localizer.text("settings.toastEnabled"), isOn: self.$store.settings.toastEnabled)
            Picker(self.localizer.text("settings.toastPosition"), selection: self.$store.settings.toastPosition) {
                ForEach(ToastPosition.allCases) { position in Text(position.label).tag(position) }
            }
            Picker(self.localizer.text("settings.toastContent"), selection: self.$store.settings.toastContentMode) {
                Text(self.localizer.text("settings.localizedText")).tag(ToastContentMode.localizedText)
                Text(self.localizer.text("settings.customText")).tag(ToastContentMode.customText)
                Text(self.localizer.text("settings.iconOnly")).tag(ToastContentMode.iconOnly)
            }
            TextField(self.localizer.text("settings.customText"), text: self.$store.settings.customToastText)
                .disabled(self.store.settings.toastContentMode != .customText)
            Picker(self.localizer.text("settings.language"), selection: self.$localizer.language) {
                Text("System").tag(AppLanguage.system)
                Text("Русский").tag(AppLanguage.russian)
                Text("English").tag(AppLanguage.english)
            }
            Toggle(self.localizer.text("settings.launchAtLogin"), isOn: Binding(
                get: { self.store.settings.launchAtLogin },
                set: { newValue in
                    self.store.settings.launchAtLogin = newValue
                    try? self.loginItem.setEnabled(newValue)
                }
            ))
            Button(self.localizer.text("menu.testToast"), action: self.showPreview)
        }
        .padding(20)
        .frame(width: 430)
    }
}
