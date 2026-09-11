import SwiftUI

struct OnboardingView: View {
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.square.fill").font(.system(size: 48)).foregroundStyle(.tint)
            Text("SelectCopy needs Accessibility permission").font(.title2.bold())
            Text("It watches text selection and copies it to the clipboard. No copy history is stored.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack {
                Button("Allow access", action: self.requestAccess).keyboardShortcut(.defaultAction)
                Button("Open System Settings", action: self.openSettings)
            }
        }
        .padding(28).frame(width: 430)
    }
}
