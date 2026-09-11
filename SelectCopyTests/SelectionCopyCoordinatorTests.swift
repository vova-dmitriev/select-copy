import CoreGraphics
@testable import SelectCopy
import XCTest

@MainActor
final class SelectionCopyCoordinatorTests: XCTestCase {
    func testAXTextWritesDirectlyAndShowsConfirmationAtGesturePoint() async {
        let fixture = CoordinatorFixture(readResult: .text("hello"))
        let point = CGPoint(x: 50, y: 60)

        fixture.coordinator.handle(SelectionGesture(kind: .drag, screenPoint: point))
        await self.waitUntil { fixture.presenter.points.count == 1 }

        XCTAssertEqual(fixture.pasteboard.writtenTexts, ["hello"])
        XCTAssertEqual(fixture.presenter.points, [point])
        XCTAssertEqual(fixture.fallback.callCount, 0)
    }

    func testSupportedAXFailureUsesSuccessfulFallback() async {
        let fixture = CoordinatorFixture(
            readResult: .unsupported(fallbackAllowed: true),
            fallbackResult: .copied("fallback")
        )

        fixture.coordinator.handle(SelectionGesture(kind: .keyboard, screenPoint: nil))
        await self.waitUntil { fixture.presenter.points.count == 1 }

        XCTAssertTrue(fixture.pasteboard.writtenTexts.isEmpty)
        XCTAssertEqual(fixture.fallback.callCount, 1)
        XCTAssertEqual(fixture.presenter.points.count, 1)
        XCTAssertNil(fixture.presenter.points[0])
    }

    func testUnsafeOrEmptyAXResultsDoNothing() async {
        let results: [SelectionReadResult] = [
            .empty,
            .secure,
            .unsupported(fallbackAllowed: false),
            .failure(.cannotComplete),
        ]

        for result in results {
            let fixture = CoordinatorFixture(readResult: result)
            fixture.coordinator.handle(SelectionGesture(kind: .drag, screenPoint: .zero))
            await self.settleTasks()

            XCTAssertTrue(fixture.pasteboard.writtenTexts.isEmpty)
            XCTAssertEqual(fixture.fallback.callCount, 0)
            XCTAssertTrue(fixture.presenter.points.isEmpty)
        }
    }

    func testDirectPasteboardFailureDoesNotRiskFallback() async {
        let fixture = CoordinatorFixture(readResult: .text("hello"), writeSucceeds: false)

        fixture.coordinator.handle(SelectionGesture(kind: .drag, screenPoint: .zero))
        await self.settleTasks()

        XCTAssertEqual(fixture.pasteboard.writtenTexts, ["hello"])
        XCTAssertEqual(fixture.fallback.callCount, 0)
        XCTAssertTrue(fixture.presenter.points.isEmpty)
    }

    func testRepeatedExplicitGestureCopiesIdenticalTextTwice() async {
        let fixture = CoordinatorFixture(readResult: .text("same"))
        let gesture = SelectionGesture(kind: .multiClick, screenPoint: .zero)

        fixture.coordinator.handle(gesture)
        await self.waitUntil { fixture.presenter.points.count == 1 }
        fixture.coordinator.handle(gesture)
        await self.waitUntil { fixture.presenter.points.count == 2 }

        XCTAssertEqual(fixture.pasteboard.writtenTexts, ["same", "same"])
    }

    func testNewGestureCancelsPendingDebounce() async {
        let fixture = CoordinatorFixture(readResult: .text("latest"), scheduler: SystemDelayScheduler())

        fixture.coordinator.handle(SelectionGesture(kind: .drag, screenPoint: CGPoint(x: 1, y: 1)))
        fixture.coordinator.handle(SelectionGesture(kind: .drag, screenPoint: CGPoint(x: 2, y: 2)))
        try? await Task.sleep(nanoseconds: 180_000_000)

        XCTAssertEqual(fixture.pasteboard.writtenTexts, ["latest"])
        XCTAssertEqual(fixture.presenter.points, [CGPoint(x: 2, y: 2)])
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0 ..< 100 where !condition() {
            await Task.yield()
        }
        XCTAssertTrue(condition())
    }

    private func settleTasks() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }
}

@MainActor
private final class CoordinatorFixture {
    let pasteboard: CoordinatorPasteboardSpy
    let fallback: CoordinatorFallbackSpy
    let presenter = CoordinatorPresenterSpy()
    let coordinator: SelectionCopyCoordinator

    init(
        readResult: SelectionReadResult,
        fallbackResult: FallbackCopyResult = .noChange,
        writeSucceeds: Bool = true,
        scheduler: DelayScheduling = ZeroDelayScheduler()
    ) {
        self.pasteboard = CoordinatorPasteboardSpy(writeSucceeds: writeSucceeds)
        self.fallback = CoordinatorFallbackSpy(result: fallbackResult)
        self.coordinator = SelectionCopyCoordinator(
            selectionReader: FixedSelectionReader(result: readResult),
            pasteboard: self.pasteboard,
            fallback: self.fallback,
            presenter: self.presenter,
            scheduler: scheduler
        )
    }
}

private struct FixedSelectionReader: SelectionReading {
    let result: SelectionReadResult

    func readSelection() -> SelectionReadResult {
        self.result
    }
}

@MainActor
private final class CoordinatorPasteboardSpy: PasteboardServicing {
    var changeCount = 0
    var writtenTexts: [String] = []
    let writeSucceeds: Bool

    init(writeSucceeds: Bool) {
        self.writeSucceeds = writeSucceeds
    }

    func writeText(_ text: String) -> Bool {
        self.writtenTexts.append(text)
        return self.writeSucceeds
    }

    func readText() -> String? {
        nil
    }

    func snapshot() -> PasteboardSnapshot {
        PasteboardSnapshot(items: [])
    }

    func restore(_: PasteboardSnapshot) -> Bool {
        true
    }
}

@MainActor
private final class CoordinatorFallbackSpy: FallbackCopying {
    let result: FallbackCopyResult
    private(set) var callCount = 0

    init(result: FallbackCopyResult) {
        self.result = result
    }

    func copySelection() async -> FallbackCopyResult {
        self.callCount += 1
        return self.result
    }
}

@MainActor
private final class CoordinatorPresenterSpy: CopyConfirmationPresenting {
    private(set) var points: [CGPoint?] = []

    func showCopyConfirmation(at screenPoint: CGPoint?) {
        self.points.append(screenPoint)
    }
}

@MainActor
private final class ZeroDelayScheduler: DelayScheduling {
    func sleep(milliseconds _: UInt64) async throws {}
}
