import CoreGraphics

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
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await scheduler.sleep(milliseconds: 100)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            await performCopy(for: gesture)
        }
    }

    func cancelPendingCopy() {
        pendingTask?.cancel()
        pendingTask = nil
    }

    private func performCopy(for gesture: SelectionGesture) async {
        switch selectionReader.readSelection() {
        case let .text(text):
            guard pasteboard.writeText(text) else {
                return
            }
            presenter?.showCopyConfirmation(at: gesture.screenPoint)
        case .unsupported(fallbackAllowed: true):
            if case .copied = await fallback.copySelection() {
                presenter?.showCopyConfirmation(at: gesture.screenPoint)
            }
        case .empty, .secure, .unsupported(fallbackAllowed: false), .failure:
            return
        }
    }
}
