import AppKit
@testable import SelectCopy
import XCTest

@MainActor
final class CopyFallbackServiceTests: XCTestCase {
    func testFileSelectionWithTextRepresentationRestoresOriginalClipboard() async {
        let original = [["public.utf8-plain-text": Data("before".utf8)]]
        let pasteboard = PasteboardServiceFake(items: original)
        let poster = KeyEventPosterFake {
            pasteboard.replaceWithText("file.txt")
            pasteboard.items[0]["public.file-url"] = Data("file:///tmp/file.txt".utf8)
        }
        let service = CopyFallbackService(
            pasteboard: pasteboard,
            keyPoster: poster,
            scheduler: ImmediateDelayScheduler()
        )
        let result = await service.copySelection()
        XCTAssertEqual(result, .rejectedNonText)
        XCTAssertEqual(pasteboard.items, original)
    }
    func testChangedPasteboardWithTextReturnsCopiedText() async {
        let pasteboard = PasteboardServiceFake(items: [["public.utf8-plain-text": Data("before".utf8)]])
        let poster = KeyEventPosterFake {
            pasteboard.replaceWithText("copied")
        }
        let scheduler = ImmediateDelayScheduler()
        let service = CopyFallbackService(pasteboard: pasteboard, keyPoster: poster, scheduler: scheduler)

        let result = await service.copySelection()

        XCTAssertEqual(result, .copied("copied"))
        XCTAssertEqual(pasteboard.restoreCallCount, 0)
    }

    func testChangedPasteboardWithNonTextRestoresOriginalContent() async {
        let original = [["public.utf8-plain-text": Data("before".utf8)]]
        let pasteboard = PasteboardServiceFake(items: original)
        let poster = KeyEventPosterFake {
            pasteboard.replaceWithNonText()
        }
        let service = CopyFallbackService(
            pasteboard: pasteboard,
            keyPoster: poster,
            scheduler: ImmediateDelayScheduler()
        )

        let result = await service.copySelection()

        XCTAssertEqual(result, .rejectedNonText)
        XCTAssertEqual(pasteboard.items, original)
        XCTAssertEqual(pasteboard.restoreCallCount, 1)
    }

    func testUnchangedPasteboardTimesOutWithoutRestore() async {
        let pasteboard = PasteboardServiceFake(items: [])
        let scheduler = ImmediateDelayScheduler()
        let service = CopyFallbackService(
            pasteboard: pasteboard,
            keyPoster: KeyEventPosterFake(),
            scheduler: scheduler
        )

        let result = await service.copySelection()

        XCTAssertEqual(result, .noChange)
        XCTAssertEqual(scheduler.sleepCallCount, 10)
        XCTAssertEqual(pasteboard.restoreCallCount, 0)
    }

    func testPostingFailureDoesNotPollOrRestore() async {
        let pasteboard = PasteboardServiceFake(items: [])
        let scheduler = ImmediateDelayScheduler()
        let service = CopyFallbackService(
            pasteboard: pasteboard,
            keyPoster: KeyEventPosterFake(succeeds: false),
            scheduler: scheduler
        )

        let result = await service.copySelection()

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(scheduler.sleepCallCount, 0)
        XCTAssertEqual(pasteboard.restoreCallCount, 0)
    }

    func testCommandCEventsCarrySyntheticMarkerAndCommandFlag() throws {
        let events = try XCTUnwrap(CommandCEventFactory().makeEvents())

        XCTAssertEqual(events.count, 2)
        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), InputEvent.syntheticSourceMarker)
            XCTAssertTrue(event.flags.contains(.maskCommand))
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 8)
        }
        XCTAssertEqual(events[0].type, .keyDown)
        XCTAssertEqual(events[1].type, .keyUp)
    }
}

@MainActor
private final class PasteboardServiceFake: PasteboardServicing {
    var items: [[String: Data]]
    private(set) var changeCount = 0
    private(set) var restoreCallCount = 0

    init(items: [[String: Data]]) {
        self.items = items
    }

    func writeText(_ text: String) -> Bool {
        self.replaceWithText(text)
        return true
    }

    func readText() -> String? {
        guard let data = items.first?["public.utf8-plain-text"] else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func snapshot() -> PasteboardSnapshot {
        PasteboardSnapshot(items: self.items)
    }

    func restore(_ snapshot: PasteboardSnapshot) -> Bool {
        self.restoreCallCount += 1
        self.items = snapshot.items
        self.changeCount += 1
        return true
    }

    func replaceWithText(_ text: String) {
        self.items = [["public.utf8-plain-text": Data(text.utf8)]]
        self.changeCount += 1
    }

    func replaceWithNonText() {
        self.items = [["public.png": Data([1, 2, 3])]]
        self.changeCount += 1
    }
}

private struct KeyEventPosterFake: KeyEventPosting {
    let succeeds: Bool
    let onPost: @MainActor () -> Void

    init(succeeds: Bool = true, onPost: @escaping @MainActor () -> Void = {}) {
        self.succeeds = succeeds
        self.onPost = onPost
    }

    @MainActor
    func postCommandC() -> Bool {
        self.onPost()
        return self.succeeds
    }
}

@MainActor
private final class ImmediateDelayScheduler: DelayScheduling {
    private(set) var sleepCallCount = 0

    func sleep(milliseconds _: UInt64) async throws {
        self.sleepCallCount += 1
    }
}
