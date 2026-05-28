import BackgroundTasks
import Foundation

/// Keeps user-initiated Whisper transcription running after the app is backgrounded (iOS 26+).
@MainActor
final class BackgroundTranscriptionCoordinator {
    static let shared = BackgroundTranscriptionCoordinator()
    static let taskIdentifier = "com.Imaginebowl.Raven.transcription"

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
            Task { @MainActor in
                await self.run(task: continuedTask)
            }
        }
    }

    /// Runs `work` under a continued background task so transcription can finish if the app is minimized.
    func execute(
        title: String,
        subtitle: String,
        work: @escaping (BGContinuedProcessingTask) async throws -> Void
    ) async throws {
        guard workBlock == nil, pendingContinuation == nil else {
            throw BackgroundTranscriptionError.alreadyRunning
        }

        workBlock = work

        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.taskIdentifier,
            title: title,
            subtitle: subtitle
        )
        request.strategy = .queue

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pendingContinuation = continuation
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                clearPendingState()
                continuation.resume(throwing: error)
            }
        }
    }

    private func run(task: BGContinuedProcessingTask) async {
        guard let work = workBlock else {
            task.setTaskCompleted(success: false)
            resumePending(with: .failure(BackgroundTranscriptionError.missingWork))
            return
        }

        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.resumePending(with: .failure(BackgroundTranscriptionError.expired))
            }
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
        let continuation = pendingContinuation
        clearPendingState()
        switch result {
        case .success:
            continuation?.resume()
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    private func clearPendingState() {
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
