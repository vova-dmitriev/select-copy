import AppKit
import ApplicationServices
import Combine

private let accessibilityPromptKey = "AXTrustedCheckOptionPrompt"

protocol AccessibilityTrustClient {
    func isTrusted(prompt: Bool) -> Bool
    func openPrivacySettings()
}

struct SystemAccessibilityTrustClient: AccessibilityTrustClient {
    func isTrusted(prompt: Bool) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }

        let options = [accessibilityPromptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class PermissionCoordinator: ObservableObject {
    @Published private(set) var isTrusted: Bool

    private let trustClient: AccessibilityTrustClient

    init(trustClient: AccessibilityTrustClient = SystemAccessibilityTrustClient()) {
        self.trustClient = trustClient
        isTrusted = trustClient.isTrusted(prompt: false)
    }

    func refresh() {
        isTrusted = trustClient.isTrusted(prompt: false)
    }

    func requestAccess() {
        isTrusted = trustClient.isTrusted(prompt: true)
    }

    func openSystemSettings() {
        trustClient.openPrivacySettings()
    }
}
