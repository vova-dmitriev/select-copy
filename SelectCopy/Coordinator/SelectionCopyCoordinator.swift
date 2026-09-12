import CoreGraphics
import OSLog

@MainActor
protocol CopyConfirmationPresenting: AnyObject {
    func showCopyConfirmation(at screenPoint: CGPoint?)
}

@MainActor
final class SelectionCopyCoordinator {
    private let selectionReader: SelectionReading
    private let pasteboard: PasteboardServicing
    private let fallback: FallbackCopying
    private weak var presenter: CopyConfirmationPresenting?
    private let scheduler: DelayScheduling
    private var pendingTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.selectcopy.app", category: "copy")

    init(
        selectionReader: SelectionReading,
        pasteboard: PasteboardServicing,
        fallback: FallbackCopying,
        presenter: CopyConfirmationPresenting,
        scheduler: DelayScheduling = SystemDelayScheduler()
    ) {
        self.selectionReader = selectionReader
        self.pasteboard = pasteboard
        self.fallback = fallback
        self.presenter = presenter
        self.scheduler = scheduler
    }

    func handle(_ gesture: SelectionGesture) {
        logger.notice("Received selection gesture")
        self.pendingTask?.cancel()
        self.pendingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.scheduler.sleep(milliseconds: 100)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            await self.performCopy(for: gesture)
        }
    }

    func cancelPendingCopy() {
        self.pendingTask?.cancel()
        self.pendingTask = nil
    }

    private func performCopy(for gesture: SelectionGesture) async {
        switch self.selectionReader.readSelection(at: gesture.screenPoint) {
        case let .text(text):
            logger.notice("Accessibility returned selected text")
            guard self.pasteboard.writeText(text) else {
                return
            }
            self.presenter?.showCopyConfirmation(at: gesture.screenPoint)
        case .unsupported(fallbackAllowed: true):
            logger.notice("Attempting Command-C fallback")
            if case .copied = await self.fallback.copySelection() {
                self.presenter?.showCopyConfirmation(at: gesture.screenPoint)
            }
        case .empty, .secure, .unsupported(fallbackAllowed: false), .failure:
            logger.notice("Selection rejected or unavailable")
            return
        }
    }
}
