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
        self.invalidate()
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
        self.handler = nil
    }

    private func receive(_ message: EventTapMessage?) {
        guard let message else {
            return
        }
        self.handler?(message)
    }

    private nonisolated static func normalize(event: CGEvent, kind: InputEvent.Kind) -> InputEvent {
        InputEvent(
            kind: kind,
            location: event.location,
            clickCount: event.getIntegerValueField(.mouseEventClickState),
            keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags,
            sourceUserData: event.getIntegerValueField(.eventSourceUserData)
        )
    }

    private nonisolated static func message(type: CGEventType, event: CGEvent) -> EventTapMessage? {
        switch type {
        case .tapDisabledByTimeout:
            .disabledByTimeout
        case .tapDisabledByUserInput:
            .disabledByUserInput
        case .leftMouseDown:
            .input(self.normalize(event: event, kind: .mouseDown))
        case .leftMouseUp:
            .input(self.normalize(event: event, kind: .mouseUp))
        case .keyUp:
            .input(self.normalize(event: event, kind: .keyUp))
        default:
            nil
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
        guard !self.isRunning else {
            return
        }

        self.onGesture = onGesture
        guard self.installTap() else {
            self.onGesture = nil
            throw SelectionMonitorError.installationFailed
        }
        self.isRunning = true
    }

    func stop() {
        guard self.isRunning else {
            return
        }
        self.eventTap.invalidate()
        self.classifier = SelectionGestureClassifier()
        self.onGesture = nil
        self.isRunning = false
    }

    private func installTap() -> Bool {
        self.eventTap.install { [weak self] message in
            self?.receive(message)
        }
    }

    private func receive(_ message: EventTapMessage) {
        switch message {
        case let .input(event):
            if let gesture = classifier.consume(event) {
                self.onGesture?(gesture)
            }
        case .disabledByTimeout, .disabledByUserInput:
            self.recoverDisabledTap()
        }
    }

    private func recoverDisabledTap() {
        self.eventTap.setEnabled(true)
        guard !self.eventTap.isEnabled else {
            return
        }

        self.eventTap.invalidate()
        self.isRunning = false
        if self.installTap() {
            self.isRunning = true
        } else {
            self.onGesture = nil
        }
    }
}
