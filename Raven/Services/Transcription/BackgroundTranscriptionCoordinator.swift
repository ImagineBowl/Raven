//
//  BackgroundTranscriptionCoordinator.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import BackgroundTasks
import Foundation

/// Keeps user-initiated Whisper transcription running under a continued background task (iOS 26+).
actor BackgroundTranscriptionCoordinator {
    static let shared = BackgroundTranscriptionCoordinator()
    static let taskIdentifier = "com.Imaginebowl.Raven.transcription"

    private var pendingContinuation: CheckedContinuation<Void, Error>?
    private var workBlock: ((BGContinuedProcessingTask) async throws -> Void)?
    private var activeTask: BGContinuedProcessingTask?

    nonisolated func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let continuedTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task(priority: .utility) {
                await BackgroundTranscriptionCoordinator.shared.run(task: continuedTask)
            }
        }
    }

    /// Cancels any in-flight continued background transcription work.
    func cancel() {
        let task = activeTask
        let continuation = pendingContinuation
        clearPendingState()
        activeTask = nil

        task?.setTaskCompleted(success: false)
        continuation?.resume(throwing: CancellationError())
    }

    /// Runs `work` under a continued background task.
    func execute(
        title: String,
        subtitle: String,
        work: @escaping (BGContinuedProcessingTask) async throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.storeAndSubmit(
                    continuation: continuation,
                    title: title,
                    subtitle: subtitle,
                    work: work
                )
            }
        }
    }

    private func storeAndSubmit(
        continuation: CheckedContinuation<Void, Error>,
        title: String,
        subtitle: String,
        work: @escaping (BGContinuedProcessingTask) async throws -> Void
    ) async {
        guard workBlock == nil, pendingContinuation == nil else {
            continuation.resume(throwing: BackgroundTranscriptionError.alreadyRunning)
            return
        }

        workBlock = work
        pendingContinuation = continuation

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

    private func run(task: BGContinuedProcessingTask) async {
        activeTask = task
        let work = workBlock

        guard let work else {
            task.setTaskCompleted(success: false)
            resumePending(with: .failure(BackgroundTranscriptionError.missingWork))
            return
        }

        task.expirationHandler = { [weak self] in
            Task {
                await self?.handleExpiration()
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

        activeTask = nil
    }

    private func handleExpiration() {
        resumePending(with: .failure(BackgroundTranscriptionError.expired))
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
