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
    @State private var showExportSheet = false
    @State private var exportURL: URL?

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
                    loadingView
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if segments.isEmpty {
                    emptyView
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
                    exportMenu
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .task {
                await loadTranscript(force: false)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var loadingView: some View {
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
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Transcription Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
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
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Transcript", systemImage: "text.quote")
        } description: {
            Text("Generate a local transcript for this chapter using Whisper.")
        } actions: {
            Button("Generate Transcript") {
                Task { await loadTranscript(force: true) }
            }
        }
    }

    private var exportMenu: some View {
        Menu {
            ForEach(SubtitleFormat.allCases) { format in
                Button("Export \(format.displayName)") {
                    let content = SubtitleExporter.export(segments: segments, format: format)
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("transcript.\(format.fileExtension)")
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                    exportURL = url
                    showExportSheet = true
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(segments.isEmpty)
    }

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            List(filteredSegments) { segment in
                TranscriptSegmentRow(
                    segment: segment,
                    isActive: segment.id == activeSegmentID
                ) {
                    player.seek(to: segment.startTime)
                }
                .id(segment.id)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .onChange(of: activeSegmentID) { _, newID in
                guard let newID else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private func loadTranscript(force: Bool) async {
        errorMessage = nil
        if !force, chapter.hasTranscript {
            segments = sanitized(chapter.sortedSegments)
            try? modelContext.save()
            return
        }

        if force {
            chapter.transcriptionState = .none
            chapter.segments.forEach { modelContext.delete($0) }
            chapter.segments = []
            try? modelContext.save()
        }

        do {
            let loaded = try await transcriptionService.ensureTranscript(
                for: chapter,
                book: book,
                modelContext: modelContext
            )
            segments = sanitized(loaded)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Cleans legacy segments saved before Whisper token stripping was enabled.
    private func sanitized(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        segments.map { segment in
            segment.text = TranscriptTextSanitizer.clean(segment.text)
            return segment
        }
    }
}

private struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment
    let isActive: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(segment.text)
                    .font(.body)
                    .foregroundStyle(isActive ? activeTextColor : .primary)
                    .fontWeight(isActive ? .semibold : .regular)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(timeRangeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isActive ? activeSecondaryTextColor : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? activeBackgroundColor : Color(.secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? activeBorderColor : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var activeTextColor: Color {
        colorScheme == .dark ? .primary : Color.accentColor
    }

    private var activeSecondaryTextColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.7) : .secondary
    }

    private var activeBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.accentColor.opacity(0.12)
    }

    private var activeBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.25) : Color.accentColor.opacity(0.35)
    }

    private var timeRangeLabel: String {
        "\(TimeFormatting.clock(segment.startTime)) – \(TimeFormatting.clock(segment.endTime))"
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
