import CoreGraphics

enum EventTapMessage: Equatable, Sendable {
    case input(InputEvent)
    case disabledByTimeout
    case disabledByUserInput
}

@MainActor
protocol EventTapServicing: AnyObject {
    var isEnabled: Bool { get }
    func install(handler: @escaping (EventTapMessage) -> Void) -> Bool
    func setEnabled(_ enabled: Bool)
    func invalidate()
}

@MainActor
final class SystemEventTapClient: EventTapServicing {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((EventTapMessage) -> Void)?

    var isEnabled: Bool {
        guard let eventTap else {
            return false
        }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func install(handler: @escaping (EventTapMessage) -> Void) -> Bool {
        invalidate()
        self.handler = handler

        let eventTypes: [CGEventType] = [.leftMouseDown, .leftMouseUp, .keyUp]
        let mask = eventTypes.reduce(CGEventMask(0)) { result, type in
            result | (CGEventMask(1) << type.rawValue)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            self.handler = nil
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            self.handler = nil
            return false
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    func setEnabled(_ enabled: Bool) {
        guard let eventTap else {
            return
        }
        CGEvent.tapEnable(tap: eventTap, enable: enabled)
    }

    func invalidate() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        handler = nil
    }

    private func receive(_ message: EventTapMessage?) {
        guard let message else {
            return
        }
        handler?(message)
    }

    nonisolated private static func normalize(event: CGEvent, kind: InputEvent.Kind) -> InputEvent {
        InputEvent(
            kind: kind,
            location: event.location,
            clickCount: event.getIntegerValueField(.mouseEventClickState),
            keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags,
            sourceUserData: event.getIntegerValueField(.eventSourceUserData)
        )
    }

    nonisolated private static func message(type: CGEventType, event: CGEvent) -> EventTapMessage? {
        switch type {
        case .tapDisabledByTimeout:
            return .disabledByTimeout
        case .tapDisabledByUserInput:
            return .disabledByUserInput
        case .leftMouseDown:
            return .input(normalize(event: event, kind: .mouseDown))
        case .leftMouseUp:
            return .input(normalize(event: event, kind: .mouseUp))
        case .keyUp:
            return .input(normalize(event: event, kind: .keyUp))
        default:
            return nil
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let client = Unmanaged<SystemEventTapClient>.fromOpaque(userInfo).takeUnretainedValue()
        let message = SystemEventTapClient.message(type: type, event: event)
        MainActor.assumeIsolated {
            client.receive(message)
        }
        return Unmanaged.passUnretained(event)
    }
}

enum SelectionMonitorError: Error, Equatable {
    case installationFailed
}

@MainActor
protocol SelectionMonitoring: AnyObject {
    func start(onGesture: @escaping (SelectionGesture) -> Void) throws
    func stop()
}

@MainActor
final class SelectionMonitor: SelectionMonitoring {
    static let syntheticEventMarker = InputEvent.syntheticSourceMarker

    private let eventTap: EventTapServicing
    private var classifier = SelectionGestureClassifier()
    private var onGesture: ((SelectionGesture) -> Void)?

    private(set) var isRunning = false

    init(eventTap: EventTapServicing = SystemEventTapClient()) {
        self.eventTap = eventTap
    }

    func start(onGesture: @escaping (SelectionGesture) -> Void) throws {
        guard !isRunning else {
            return
        }

        self.onGesture = onGesture
        guard installTap() else {
            self.onGesture = nil
            throw SelectionMonitorError.installationFailed
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else {
            return
        }
        eventTap.invalidate()
        classifier = SelectionGestureClassifier()
        onGesture = nil
        isRunning = false
    }

    private func installTap() -> Bool {
        eventTap.install { [weak self] message in
            self?.receive(message)
        }
    }

    private func receive(_ message: EventTapMessage) {
        switch message {
        case let .input(event):
            if let gesture = classifier.consume(event) {
                onGesture?(gesture)
            }
        case .disabledByTimeout, .disabledByUserInput:
            recoverDisabledTap()
        }
    }

    private func recoverDisabledTap() {
        eventTap.setEnabled(true)
        guard !eventTap.isEnabled else {
            return
        }

        eventTap.invalidate()
        isRunning = false
        if installTap() {
            isRunning = true
        } else {
            onGesture = nil
        }
    }
}
