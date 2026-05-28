import BackgroundTasks
import Foundation

/// Keeps user-initiated Whisper transcription running after the app is backgrounded (iOS 26+).
final class BackgroundTranscriptionCoordinator: @unchecked Sendable {
    static let shared = BackgroundTranscriptionCoordinator()
    static let taskIdentifier = "com.Imaginebowl.Raven.transcription"

    private let lock = NSLock()
    private var pendingContinuation: CheckedContinuation<Void, Error>?
    private var workBlock: ((BGContinuedProcessingTask) async throws -> Void)?

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let continuedTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task(priority: .utility) {
                await self.run(task: continuedTask)
            }
        }
    }

    /// Runs `work` under a continued background task so transcription can finish if the app is minimized.
    func execute(
        title: String,
        subtitle: String,
        work: @escaping @Sendable (BGContinuedProcessingTask) async throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            if workBlock != nil || pendingContinuation != nil {
                lock.unlock()
                continuation.resume(throwing: BackgroundTranscriptionError.alreadyRunning)
                return
            }
            workBlock = work
            pendingContinuation = continuation
            lock.unlock()

            let request = BGContinuedProcessingTaskRequest(
                identifier: Self.taskIdentifier,
                title: title,
                subtitle: subtitle
            )
            request.strategy = .queue

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                clearPendingState()
                continuation.resume(throwing: error)
            }
        }
    }

    private func run(task: BGContinuedProcessingTask) async {
        lock.lock()
        let work = workBlock
        lock.unlock()

        guard let work else {
            task.setTaskCompleted(success: false)
            resumePending(with: .failure(BackgroundTranscriptionError.missingWork))
            return
        }

        task.expirationHandler = { [weak self] in
            self?.resumePending(with: .failure(BackgroundTranscriptionError.expired))
        }

        do {
            try await work(task)
            task.setTaskCompleted(success: true)
            resumePending(with: .success(()))
        } catch {
            task.setTaskCompleted(success: false)
            resumePending(with: .failure(error))
        }
    }

    private func resumePending(with result: Result<Void, Error>) {
        lock.lock()
        let continuation = pendingContinuation
        clearPendingStateLocked()
        lock.unlock()

        switch result {
        case .success:
            continuation?.resume()
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    private func clearPendingState() {
        lock.lock()
        clearPendingStateLocked()
        lock.unlock()
    }

    private func clearPendingStateLocked() {
        pendingContinuation = nil
        workBlock = nil
    }
}

enum BackgroundTranscriptionError: LocalizedError {
    case alreadyRunning
    case missingWork
    case expired

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "Another transcription is already running."
        case .missingWork:
            "Could not start the background transcription task."
        case .expired:
            "Transcription was interrupted because the system needed resources. Try again."
        }
    }
}
