//
//  TranscriptionService.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation
import SwiftData

enum TranscriptionError: LocalizedError {
    case chapterNotFound
    case audioFileNotFound
    case emptyTranscript
    case engineUnavailable(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .chapterNotFound:
            "Chapter not found."
        case .audioFileNotFound:
            "Could not access the chapter audio file."
        case .emptyTranscript:
            "No transcript segments were returned for this chapter."
        case .engineUnavailable(let message):
            message
        case .cancelled:
            "Transcription was stopped."
        }
    }
}

@MainActor
@Observable
final class TranscriptionService {
    private(set) var activeChapterID: UUID?
    private(set) var progressMessage = ""
    private(set) var isProcessing = false

    private let whisperEngine = WhisperKitTranscriptionEngine.shared
    private var activeTranscriptionTask: Task<[TimedSegment], Error>?
    private var processingChapter: Chapter?

    var isWhisperAvailable: Bool {
        get async {
            await whisperEngine.isModelAvailable()
        }
    }

    func resetEngineCache() async {
        await whisperEngine.resetModelCache()
    }

    /// Cancels in-flight transcription (for example when the user switches chapters).
    func cancelActiveTranscription(modelContext: ModelContext) {
        guard isProcessing else { return }

        activeTranscriptionTask?.cancel()
        Task { await BackgroundTranscriptionCoordinator.shared.cancel() }
        Task { await whisperEngine.cancelActiveWork() }

        if let chapter = processingChapter {
            chapter.transcriptionState = .none
            try? modelContext.save()
        }

        activeTranscriptionTask = nil
        processingChapter = nil
        isProcessing = false
        activeChapterID = nil
        progressMessage = ""
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
        progressMessage = "Preparing Whisper…"
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

        let usesSegment = chapterUsesSegmentExport(chapter, in: book)
        var transcriptionURL = audioURL
        var temporaryURL: URL?

        if usesSegment {
            temporaryURL = try await AudioChapterSegmentExporter.exportSegment(
                from: audioURL,
                startTime: chapter.startTime,
                duration: chapter.duration
            )
            transcriptionURL = temporaryURL!
        }

        defer {
            if let temporaryURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }

        progressMessage = "Transcribing \"\(chapter.title)\"…"

        let timedSegments: [TimedSegment]
        do {
            activeTranscriptionTask = Task {
                try await runTranscriptionJob(
                    audioURL: transcriptionURL,
                    chapterTitle: chapter.title
                )
            }
            timedSegments = try await activeTranscriptionTask!.value
        } catch is CancellationError {
            chapter.transcriptionState = .none
            try? modelContext.save()
            throw TranscriptionError.cancelled
        } catch let error as WhisperModelError {
            chapter.transcriptionState = .failed
            try? modelContext.save()
            throw TranscriptionError.engineUnavailable(error.localizedDescription)
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

    private func runTranscriptionJob(audioURL: URL, chapterTitle: String) async throws -> [TimedSegment] {
        let throttler = ProgressThrottler(minimumInterval: 0.5)
        let engine = whisperEngine
        let resultBox = TranscriptionResultBox()

        try await BackgroundTranscriptionCoordinator.shared.execute(
            title: "Transcribing Audiobook",
            subtitle: chapterTitle
        ) { _ in
            let segments = try await engine.transcribe(audioURL: audioURL) { message in
                throttler.report(message) { throttledMessage in
                    Task { @MainActor in
                        self.progressMessage = throttledMessage
                    }
                }
            }
            resultBox.store(segments)
        }

        return resultBox.value
    }

    private func chapterUsesSegmentExport(_ chapter: Chapter, in book: Book) -> Bool {
        if chapter.startTime > 0 { return true }
        return book.sortedChapters.filter { $0.relativePath == chapter.relativePath }.count > 1
    }
}

private final class TranscriptionResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var segments: [TimedSegment] = []

    func store(_ segments: [TimedSegment]) {
        lock.lock()
        self.segments = segments
        lock.unlock()
    }

    var value: [TimedSegment] {
        lock.lock()
        defer { lock.unlock() }
        return segments
    }
}
