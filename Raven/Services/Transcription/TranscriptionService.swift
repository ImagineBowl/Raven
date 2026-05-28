import BackgroundTasks
import Foundation
import SwiftData

enum TranscriptionError: LocalizedError {
    case chapterNotFound
    case audioFileNotFound
    case emptyTranscript
    case modelUnavailable(String)

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
        }
    }
}

@MainActor
@Observable
final class TranscriptionService {
    private(set) var activeChapterID: UUID?
    private(set) var progressMessage = ""
    private(set) var isProcessing = false

    private let engine = WhisperKitTranscriptionEngine.shared

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
        progressMessage = "Preparing Whisper model…"
        chapter.transcriptionState = .processing

        defer {
            isProcessing = false
            activeChapterID = nil
            progressMessage = ""
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
            timedSegments = try await runTranscriptionJob(audioURL: audioURL, chapterTitle: chapterTitle)
        } catch let error as WhisperModelError {
            chapter.transcriptionState = .failed
            try? modelContext.save()
            throw TranscriptionError.modelUnavailable(error.localizedDescription ?? "Whisper model error.")
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
        segments.first { time >= $0.startTime && time < $0.endTime }
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
        try await Task.detached(priority: .utility) { [engine] in
            let throttler = ProgressThrottler(minimumInterval: 1.0)
            var timedSegments: [TimedSegment] = []
            try await BackgroundTranscriptionCoordinator.shared.execute(
                title: "Transcribing",
                subtitle: chapterTitle
            ) { task in
                timedSegments = try await engine.transcribe(audioURL: audioURL) { message in
                    throttler.report(message) { throttledMessage in
                        Task { @MainActor in
                            self.updateProgress(throttledMessage, backgroundTask: task)
                        }
                    }
                }
            }
            return timedSegments
        }.value
    }

    private func updateProgress(_ message: String, backgroundTask: BGContinuedProcessingTask) {
        progressMessage = message
        backgroundTask.updateTitle("Transcribing", subtitle: message)
    }
}
