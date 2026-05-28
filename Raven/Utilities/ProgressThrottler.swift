import Foundation

/// Coalesces high-frequency progress callbacks so UI updates stay smooth during heavy work.
final class ProgressThrottler: @unchecked Sendable {
    private let minimumInterval: TimeInterval
    private var lastDelivered = Date.distantPast
    private var lastMessage: String?
    private let lock = NSLock()

    init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
    }

    func report(_ message: String, deliver: @Sendable (String) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let isNewMessage = message != lastMessage
        guard isNewMessage, now.timeIntervalSince(lastDelivered) >= minimumInterval else { return }

        lastDelivered = now
        lastMessage = message
        deliver(message)
    }

    func flush(_ message: String, deliver: @Sendable (String) -> Void) {
        lock.lock()
        lastDelivered = Date()
        lastMessage = message
        lock.unlock()
        deliver(message)
    }
}
