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
        promptValues.append(prompt)
        return values.isEmpty ? false : values.removeFirst()
    }

    func openPrivacySettings() {
        openPrivacySettingsCallCount += 1
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
        installCallCount += 1
        self.handler = handler
        let result = installResults.isEmpty ? false : installResults.removeFirst()
        isEnabled = result
        return result
    }

    func setEnabled(_ enabled: Bool) {
        setEnabledValues.append(enabled)
        isEnabled = enabled && enableSucceeds
    }

    func invalidate() {
        invalidateCallCount += 1
        isEnabled = false
    }

    func emit(_ message: EventTapMessage) {
        handler?(message)
    }
}
