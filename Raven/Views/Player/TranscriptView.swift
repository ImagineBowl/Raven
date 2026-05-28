import SwiftData
import SwiftUI
import UIKit

struct TranscriptView: View {
    let book: Book
    let chapter: Chapter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var player
    @Environment(TranscriptionService.self) private var transcriptionService

    @State private var segments: [TranscriptSegment] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var exportFormat: SubtitleFormat = .srt
    @State private var showExportSheet = false
    @State private var exportDocument: ExportSubtitleDocument?

    private var filteredSegments: [TranscriptSegment] {
        transcriptionService.search(searchText, in: segments)
    }

    private var activeSegmentID: UUID? {
        guard player.currentBook?.id == book.id,
              player.currentChapter?.id == chapter.id else { return nil }
        return transcriptionService.segment(at: player.currentTime, in: segments)?.id
    }

    var body: some View {
        NavigationStack {
            Group {
                if transcriptionService.isProcessing && transcriptionService.activeChapterID == chapter.id {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(transcriptionService.progressMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("First run downloads the Whisper model (~140 MB). Transcripts are saved locally.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Transcription Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            Task { await loadTranscript(force: true) }
                        }
                        Button("Reset Whisper Model") {
                            Task {
                                await transcriptionService.resetWhisperModel()
                                await loadTranscript(force: true)
                            }
                        }
                    }
                } else if segments.isEmpty {
                    ContentUnavailableView {
                        Label("No Transcript", systemImage: "text.quote")
                    } description: {
                        Text("Generate a local transcript for this chapter using Whisper.")
                    } actions: {
                        Button("Generate Transcript") {
                            Task { await loadTranscript(force: true) }
                        }
                    }
                } else {
                    transcriptList
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search in chapter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(SubtitleFormat.allCases) { format in
                            Button("Export \(format.displayName)") {
                                exportDocument = ExportSubtitleDocument(
                                    content: SubtitleExporter.export(segments: segments, format: format),
                                    format: format
                                )
                                showExportSheet = true
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(segments.isEmpty)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let exportDocument {
                    ShareSheet(items: [exportDocument.url])
                }
            }
            .task {
                await loadTranscript(force: false)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            List(filteredSegments) { segment in
                Button {
                    player.seek(to: segment.startTime)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(segment.text)
                            .foregroundStyle(segment.id == activeSegmentID ? Color.accentColor : .primary)
                            .fontWeight(segment.id == activeSegmentID ? .semibold : .regular)
                        Text(TimeFormatting.clock(segment.startTime))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(segment.id)
            }
            .listStyle(.plain)
            .onChange(of: activeSegmentID) { _, newID in
                guard let newID else { return }
                withAnimation {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private func loadTranscript(force: Bool) async {
        errorMessage = nil
        if !force, chapter.hasTranscript {
            segments = chapter.sortedSegments
            return
        }

        if force {
            chapter.transcriptionState = .none
            chapter.segments.forEach { modelContext.delete($0) }
            chapter.segments = []
            try? modelContext.save()
        }

        do {
            segments = try await transcriptionService.ensureTranscript(
                for: chapter,
                book: book,
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ExportSubtitleDocument {
    let content: String
    let format: SubtitleFormat

    var url: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcript.\(format.fileExtension)")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
