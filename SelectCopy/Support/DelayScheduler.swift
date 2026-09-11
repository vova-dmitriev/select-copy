import Foundation

@MainActor
protocol DelayScheduling: AnyObject {
    func sleep(milliseconds: UInt64) async throws
}

@MainActor
final class SystemDelayScheduler: DelayScheduling {
    func sleep(milliseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
}
