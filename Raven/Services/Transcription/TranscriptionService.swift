//
//  TranscriptionService.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

@preconcurrency import BackgroundTasks
import Foundation
import SwiftData

enum TranscriptionError: LocalizedError {
    case chapterNotFound
    case audioFileNotFound
    case emptyTranscript
    case modelUnavailable(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .chapterNotFound:
            "Chapter not found."
        case .audioFileNotFound:
            "Could not access the chapter audio file."
        case .emptyTranscript:
            "Whisper returned no transcript segments for this chapter."
        case .modelUnavailable(let message):
            message
        case .cancelled:
            "Transcription was stopped."
        }
    }
}

@MainActor
@Observable
final class TranscriptionService {
    static let whisperModelDownloadSize = WhisperKitTranscriptionEngine.estimatedDownloadSize

    private(set) var activeChapterID: UUID?
    private(set) var progressMessage = ""
    private(set) var isProcessing = false
    private(set) var isDownloadingModel = false

    private let engine = WhisperKitTranscriptionEngine.shared
    private var activeTranscriptionTask: Task<[TimedSegment], Error>?
    private var processingChapter: Chapter?

    /// Stops in-flight transcription or model download when the app is minimized or the device is locked.
    func suspendForBackground(modelContext: ModelContext) {
        guard isProcessing || isDownloadingModel else { return }

        activeTranscriptionTask?.cancel()
        Task { await BackgroundTranscriptionCoordinator.shared.cancel() }
        Task { await engine.cancelActiveWork() }

        if isProcessing, let chapter = processingChapter {
            chapter.transcriptionState = .none
            try? modelContext.save()
        }

        activeTranscriptionTask = nil
        processingChapter = nil
        isProcessing = false
        isDownloadingModel = false
        activeChapterID = nil
        progressMessage = ""
    }

    func isWhisperModelInstalled() async -> Bool {
        await engine.isModelInstalled()
    }

    func downloadWhisperModel() async throws {
        guard !isDownloadingModel else { return }

        isDownloadingModel = true
        progressMessage = "Checking Whisper model…"

        defer {
            isDownloadingModel = false
            progressMessage = ""
        }

        do {
            try await engine.downloadModelIfNeeded { message in
                Task { @MainActor in
                    self.progressMessage = message
                }
            }
        } catch let error as WhisperModelError {
            throw TranscriptionError.modelUnavailable(error.localizedDescription)
        }
    }

    /// Returns cached segments or transcribes the chapter, saves locally, then returns segments.
    func ensureTranscript(for chapter: Chapter, book: Book, modelContext: ModelContext) async throws -> [TranscriptSegment] {
        if chapter.hasTranscript {
            return chapter.sortedSegments
        }

        guard activeChapterID != chapter.id else {
            while isProcessing {
                try await Task.sleep(for: .milliseconds(200))
            }
            return chapter.sortedSegments
        }

        activeChapterID = chapter.id
        isProcessing = true
        processingChapter = chapter
        progressMessage = "Preparing Whisper model…"
        chapter.transcriptionState = .processing

        defer {
            isProcessing = false
            activeChapterID = nil
            processingChapter = nil
            progressMessage = ""
            activeTranscriptionTask = nil
        }

        let folderURL = try BookFolderAccess.openFolder(for: book)
        defer { BookFolderAccess.releaseFolder(folderURL, for: book) }

        let audioURL = folderURL.appendingPathComponent(chapter.relativePath)
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            chapter.transcriptionState = .failed
            try? modelContext.save()
            throw TranscriptionError.audioFileNotFound
        }

        progressMessage = "Transcribing \"\(chapter.title)\"…"
        let chapterTitle = chapter.title

        let timedSegments: [TimedSegment]
        do {
            activeTranscriptionTask = Task {
                try await runTranscriptionJob(audioURL: audioURL, chapterTitle: chapterTitle)
            }
            timedSegments = try await activeTranscriptionTask!.value
        } catch is CancellationError {
            chapter.transcriptionState = .none
            try? modelContext.save()
            throw TranscriptionError.cancelled
        } catch let error as WhisperModelError {
            chapter.transcriptionState = .failed
            try? modelContext.save()
            throw TranscriptionError.modelUnavailable(error.localizedDescription)
        } catch {
            chapter.transcriptionState = .failed
            try? modelContext.save()
            throw error
        }

        guard !timedSegments.isEmpty else {
            chapter.transcriptionState = .failed
            try? modelContext.save()
            throw TranscriptionError.emptyTranscript
        }

        chapter.segments.forEach { modelContext.delete($0) }
        chapter.segments = timedSegments.enumerated().map { index, segment in
            TranscriptSegment(
                startTime: segment.startTime,
                endTime: segment.endTime,
                text: TranscriptTextSanitizer.clean(segment.text),
                sortOrder: index
            )
        }
        chapter.transcriptionState = .completed
        try modelContext.save()
        return chapter.sortedSegments
    }

    func segment(at time: TimeInterval, in segments: [TranscriptSegment]) -> TranscriptSegment? {
        TranscriptSegmentLookup.segment(at: time, in: segments)
    }

    func search(_ query: String, in segments: [TranscriptSegment]) -> [TranscriptSegment] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return segments }
        return segments.filter {
            $0.text.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func resetWhisperModel() async {
        await engine.resetModelCache()
    }

    private func runTranscriptionJob(audioURL: URL, chapterTitle: String) async throws -> [TimedSegment] {
        let throttler = ProgressThrottler(minimumInterval: 1.0)
        let result = TranscriptionResultBox()
        try await BackgroundTranscriptionCoordinator.shared.execute(
            title: "Transcribing",
            subtitle: chapterTitle
        ) { task in
            result.segments = try await self.engine.transcribe(audioURL: audioURL) { message in
                throttler.report(message) { throttledMessage in
                    Task { @MainActor in
                        self.updateProgress(throttledMessage, backgroundTask: task)
                    }
                }
            }
        }
        return result.segments
    }

    private func updateProgress(_ message: String, backgroundTask: BGContinuedProcessingTask) {
        progressMessage = message
        backgroundTask.updateTitle("Transcribing", subtitle: message)
    }
}

private final class TranscriptionResultBox: @unchecked Sendable {
    var segments: [TimedSegment] = []
}
