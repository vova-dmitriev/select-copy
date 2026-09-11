import CoreGraphics

enum FallbackCopyResult: Equatable {
    case copied(String)
    case noChange
    case rejectedNonText
    case failed
}

@MainActor
protocol FallbackCopying: AnyObject {
    func copySelection() async -> FallbackCopyResult
}

struct CommandCEventFactory {
    func makeEvents() -> [CGEvent]? {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        else {
            return nil
        }

        for event in [keyDown, keyUp] {
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: InputEvent.syntheticSourceMarker)
        }
        return [keyDown, keyUp]
    }
}

@MainActor
protocol KeyEventPosting {
    func postCommandC() -> Bool
}

struct SystemKeyEventPoster: KeyEventPosting {
    private let factory = CommandCEventFactory()

    func postCommandC() -> Bool {
        guard let events = factory.makeEvents() else {
            return false
        }
        events.forEach { $0.post(tap: .cghidEventTap) }
        return true
    }
}

@MainActor
final class CopyFallbackService: FallbackCopying {
    private let pasteboard: PasteboardServicing
    private let keyPoster: KeyEventPosting
    private let scheduler: DelayScheduling
    private let pollIntervalMilliseconds: UInt64
    private let maximumPollCount: Int

    init(
        pasteboard: PasteboardServicing,
        keyPoster: KeyEventPosting = SystemKeyEventPoster(),
        scheduler: DelayScheduling = SystemDelayScheduler(),
        pollIntervalMilliseconds: UInt64 = 25,
        maximumPollCount: Int = 10
    ) {
        self.pasteboard = pasteboard
        self.keyPoster = keyPoster
        self.scheduler = scheduler
        self.pollIntervalMilliseconds = pollIntervalMilliseconds
        self.maximumPollCount = maximumPollCount
    }

    func copySelection() async -> FallbackCopyResult {
        let originalSnapshot = self.pasteboard.snapshot()
        let originalChangeCount = self.pasteboard.changeCount
        guard self.keyPoster.postCommandC() else {
            return .failed
        }

        do {
            for _ in 0 ..< self.maximumPollCount {
                if self.pasteboard.changeCount != originalChangeCount {
                    guard let text = pasteboard.readText(), !text.isEmpty else {
                        _ = self.pasteboard.restore(originalSnapshot)
                        return .rejectedNonText
                    }
                    return .copied(text)
                }
                try await self.scheduler.sleep(milliseconds: self.pollIntervalMilliseconds)
            }
            return .noChange
        } catch {
            return .failed
        }
    }
}
