import CoreGraphics
@testable import SelectCopy

final class AccessibilityTrustClientSpy: AccessibilityTrustClient {
    private var values: [Bool]
    private(set) var promptValues: [Bool] = []
    private(set) var openPrivacySettingsCallCount = 0

    init(values: [Bool]) {
        self.values = values
    }

    func isTrusted(prompt: Bool) -> Bool {
        self.promptValues.append(prompt)
        return self.values.isEmpty ? false : self.values.removeFirst()
    }

    func openPrivacySettings() {
        self.openPrivacySettingsCallCount += 1
    }
}

@MainActor
final class EventTapClientSpy: EventTapServicing {
    var installResults: [Bool] = [true]
    var enableSucceeds = true
    private(set) var installCallCount = 0
    private(set) var invalidateCallCount = 0
    private(set) var setEnabledValues: [Bool] = []
    private var handler: ((EventTapMessage) -> Void)?

    var isEnabled = false

    func install(handler: @escaping (EventTapMessage) -> Void) -> Bool {
        self.installCallCount += 1
        self.handler = handler
        let result = self.installResults.isEmpty ? false : self.installResults.removeFirst()
        self.isEnabled = result
        return result
    }

    func setEnabled(_ enabled: Bool) {
        self.setEnabledValues.append(enabled)
        self.isEnabled = enabled && self.enableSucceeds
    }

    func invalidate() {
        self.invalidateCallCount += 1
        self.isEnabled = false
    }

    func emit(_ message: EventTapMessage) {
        self.handler?(message)
    }
}
