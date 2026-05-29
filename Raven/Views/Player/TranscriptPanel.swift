//
//  TranscriptPanel.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftData
import SwiftUI
import UIKit

struct TranscriptPanel: View {
    let book: Book
    let chapter: Chapter
    var isPlayerCollapsed = false
    var onPlayerCollapseChange: ((Bool) -> Void)?
    var onScrollOffsetChange: ((CGFloat) -> Void)?
    var usesPlayerDarkTheme = false

    @Environment(\.modelContext) private var modelContext
    @Environment(TranscriptionService.self) private var transcriptionService

    @State private var segments: [TranscriptSegment] = []
    @State private var errorMessage: String?
    @State private var setupRequirement: TranscriptionSetupRequirement?
    @State private var readinessChecked = false

    @AppStorage(TranscriptionSettings.storageKey) private var engineKindRaw = TranscriptionEngineKind.appleSpeech.rawValue

    private var isProcessingThisChapter: Bool {
        transcriptionService.isProcessing && transcriptionService.activeChapterID == chapter.id
    }

    private var hasTranscriptContent: Bool {
        chapter.hasTranscript || !segments.isEmpty
    }

    private var showsPlayerCollapseHandle: Bool {
        hasTranscriptContent && !isProcessingThisChapter && !transcriptionService.isPreparingEngine
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader

            Group {
                if transcriptionService.isPreparingEngine {
                    TranscriptLoadingView(
                        message: transcriptionService.progressMessage,
                        footnote: preparationFootnote,
                        usesPlayerDarkTheme: usesPlayerDarkTheme
                    )
                } else if isProcessingThisChapter {
                    TranscriptLoadingView(
                        message: transcriptionService.progressMessage,
                        footnote: nil,
                        usesPlayerDarkTheme: usesPlayerDarkTheme
                    )
                } else if let errorMessage {
                    errorView(errorMessage)
                } else if !readinessChecked {
                    ProgressView()
                        .tint(usesPlayerDarkTheme ? .white : .accentColor)
                } else if segments.isEmpty, let setupRequirement {
                    engineSetupPrompt(requirement: setupRequirement)
                } else if segments.isEmpty {
                    emptyView
                } else {
                    TranscriptLyricsScrollView(
                        bookID: book.id,
                        chapterID: chapter.id,
                        segments: segments,
                        onScrollOffsetChange: onScrollOffsetChange,
                        usesPlayerDarkTheme: usesPlayerDarkTheme
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(usesPlayerDarkTheme ? RavenDesign.Colors.playerSurface : Color(.systemGroupedBackground))
        .task(id: chapter.id) {
            await refreshPanelState()
        }
        .onChange(of: engineKindRaw) { _, _ in
            Task { await refreshPanelState() }
        }
    }

    private var preparationFootnote: String? {
        switch TranscriptionSettings.engineKind {
        case .appleSpeech:
            nil
        case .whisper:
            "One-time download · \(TranscriptionService.whisperModelDownloadSize)"
        }
    }

    private func refreshPanelState() async {
        errorMessage = nil
        if chapter.hasTranscript {
            segments = sanitized(chapter.sortedSegments)
            if TranscriptSegmentGrouper.isWordLevel(segments) {
                regroupStoredSegments()
            }
        } else {
            segments = []
        }

        switch await transcriptionService.readinessStatus() {
        case .ready:
            setupRequirement = nil
        case .needsSetup(let requirement):
            setupRequirement = requirement
        }
        readinessChecked = true
    }

    private func regroupStoredSegments() {
        let grouped = TranscriptSegmentGrouper.normalizeStored(segments)
        chapter.segments.forEach { modelContext.delete($0) }
        chapter.segments = grouped.enumerated().map { index, segment in
            TranscriptSegment(
                startTime: segment.startTime,
                endTime: segment.endTime,
                text: segment.text,
                sortOrder: index
            )
        }
        try? modelContext.save()
        segments = sanitized(chapter.sortedSegments)
    }

    private var panelHeader: some View {
        ZStack {
            HStack {
                Text("Transcript")
                    .font(.headline)
                    .foregroundStyle(usesPlayerDarkTheme ? .white : .primary)

                Spacer(minLength: 0)

                exportMenu
            }

            if showsPlayerCollapseHandle, let onPlayerCollapseChange {
                PlayerCollapseHandle(
                    isCollapsed: isPlayerCollapsed,
                    usesPlayerDarkTheme: usesPlayerDarkTheme,
                    onSetCollapsed: onPlayerCollapseChange
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(usesPlayerDarkTheme ? RavenDesign.Colors.playerSurface : Color(.systemGroupedBackground))
    }

    private func errorView(_ message: String) -> some View {
        TranscriptPlaceholderView(
            title: "Transcription Failed",
            systemImage: "exclamationmark.triangle",
            message: message,
            usesPlayerDarkTheme: usesPlayerDarkTheme
        ) {
            VStack(spacing: 12) {
                TranscriptPlaceholderButton(title: "Try Again", usesPlayerDarkTheme: usesPlayerDarkTheme) {
                    Task { await loadTranscript(force: true) }
                }
                if TranscriptionSettings.engineKind == .whisper {
                    Button("Reset Whisper Model") {
                        Task {
                            await transcriptionService.resetEngineStorage()
                            await refreshPanelState()
                        }
                    }
                    .font(RavenDesign.Typography.bodyUI())
                    .foregroundStyle(usesPlayerDarkTheme ? .white.opacity(0.6) : .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func engineSetupPrompt(requirement: TranscriptionSetupRequirement) -> some View {
        switch requirement {
        case .speechAuthorization:
            TranscriptPlaceholderView(
                title: "Speech Recognition Required",
                systemImage: "waveform.badge.mic",
                message: "Raven uses on-device Apple Speech to transcribe this chapter. Nothing runs until you allow access.",
                footnote: "Uses \(TranscriptionSettings.engineKind.title)",
                usesPlayerDarkTheme: usesPlayerDarkTheme
            ) {
                TranscriptPlaceholderButton(title: "Enable Transcription", usesPlayerDarkTheme: usesPlayerDarkTheme) {
                    Task { await prepareEngine() }
                }
            }

        case .whisperModelDownload(let size):
            TranscriptPlaceholderView(
                title: "Whisper Model Required",
                systemImage: "arrow.down.circle",
                message: "Transcripts run on-device with Whisper. Nothing is downloaded until you choose to.",
                footnote: "One-time download · \(size)",
                usesPlayerDarkTheme: usesPlayerDarkTheme
            ) {
                TranscriptPlaceholderButton(title: "Download Model", usesPlayerDarkTheme: usesPlayerDarkTheme) {
                    Task { await prepareEngine() }
                }
            }
        }
    }

    private var emptyView: some View {
        TranscriptPlaceholderView(
            title: "No Transcript",
            systemImage: "text.quote",
            message: "Generate a local transcript for this chapter.",
            usesPlayerDarkTheme: usesPlayerDarkTheme
        ) {
            TranscriptPlaceholderButton(title: "Generate Transcript", usesPlayerDarkTheme: usesPlayerDarkTheme) {
                Task { await loadTranscript(force: true) }
            }
        }
    }

    private var exportMenu: some View {
        Menu {
            if !segments.isEmpty {
                Button("Regenerate Transcript") {
                    Task { await loadTranscript(force: true) }
                }
            }

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
        .sheet(isPresented: $showExportSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    @State private var showExportSheet = false
    @State private var exportURL: URL?

    private func prepareEngine() async {
        errorMessage = nil
        do {
            try await transcriptionService.prepareEngine()
            await refreshPanelState()
        } catch {
            errorMessage = error.localizedDescription
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
        } catch TranscriptionError.cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sanitized(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        segments.map { segment in
            segment.text = TranscriptTextSanitizer.clean(segment.text)
            return segment
        }
    }
}

struct TranscriptPeekView: View {
    let book: Book
    let chapter: Chapter
    var onExpand: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(TranscriptionService.self) private var transcriptionService
    @Environment(AudioPlayerService.self) private var player

    @State private var segments: [TranscriptSegment] = []

    var body: some View {
        Button(action: onExpand) {
            VStack(spacing: 12) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 32, height: 4)

                ZStack(alignment: .bottom) {
                    VStack(spacing: 8) {
                        if let previousLine {
                            Text(previousLine)
                                .font(RavenDesign.Typography.transcriptActive())
                                .foregroundStyle(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .scaleEffect(0.95)
                        }

                        if let activeLine {
                            Text(activeLine)
                                .font(RavenDesign.Typography.transcriptActive())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        } else if segments.isEmpty {
                            Text("Tap to open transcript")
                                .font(RavenDesign.Typography.bodyUI())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    LinearGradient(
                        colors: [RavenDesign.Colors.playerSurface.opacity(0), RavenDesign.Colors.playerSurface],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 36)
                    .allowsHitTesting(false)
                }
                .frame(maxHeight: 96)
            }
            .padding(.top, RavenDesign.Spacing.stackMedium)
        }
        .buttonStyle(.plain)
        .task(id: chapter.id) {
            await loadSegments()
        }
    }

    private var activeLine: String? {
        guard let segment = TranscriptSegmentLookup.segment(at: player.currentTime, in: segments) else {
            return segments.first?.text
        }
        return segment.text
    }

    private var previousLine: String? {
        guard let activeIndex = segments.firstIndex(where: { $0.id == TranscriptSegmentLookup.segment(at: player.currentTime, in: segments)?.id }),
              activeIndex > 0 else {
            return nil
        }
        return segments[activeIndex - 1].text
    }

    private func loadSegments() async {
        if chapter.hasTranscript {
            segments = sanitized(chapter.sortedSegments)
        } else {
            segments = []
        }
    }

    private func sanitized(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        segments.map { segment in
            segment.text = TranscriptTextSanitizer.clean(segment.text)
            return segment
        }
    }
}

/// Isolates playback-driven highlight updates from the rest of the transcript panel.
private struct TranscriptLyricsScrollView: View {
    let bookID: UUID
    let chapterID: UUID
    let segments: [TranscriptSegment]
    var onScrollOffsetChange: ((CGFloat) -> Void)?
    var usesPlayerDarkTheme = false

    @Environment(AudioPlayerService.self) private var player

    @State private var activeSegmentID: UUID?
    @State private var userIsScrolling = false
    @State private var lastReportedOffset: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(segments) { segment in
                        TranscriptLyricsLine(
                            text: segment.text,
                            isActive: segment.id == activeSegmentID,
                            usesPlayerDarkTheme: usesPlayerDarkTheme,
                            onTap: { player.seek(to: segment.startTime) }
                        )
                        .equatable()
                        .id(segment.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, newPhase in
                userIsScrolling = newPhase == .interacting || newPhase == .decelerating
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                guard abs(offset - lastReportedOffset) > 6 else { return }
                lastReportedOffset = offset
                onScrollOffsetChange?(offset)
            }
            .onChange(of: player.currentTime) { _, time in
                updateActiveSegment(for: time, scrollProxy: proxy)
            }
            .onAppear {
                updateActiveSegment(for: player.currentTime, scrollProxy: proxy)
            }
        }
    }

    private func updateActiveSegment(for time: TimeInterval, scrollProxy: ScrollViewProxy) {
        guard player.currentBook?.id == bookID,
              player.currentChapter?.id == chapterID else { return }

        let newID = TranscriptSegmentLookup.segment(at: time, in: segments)?.id
        guard newID != activeSegmentID else { return }

        activeSegmentID = newID
        guard let newID, !userIsScrolling else { return }

        scrollProxy.scrollTo(newID, anchor: .center)
    }
}

/// Lightweight row that only re-renders when its active state or text changes.
private struct TranscriptLyricsLine: View, Equatable {
    let text: String
    let isActive: Bool
    var usesPlayerDarkTheme = false
    let onTap: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text == rhs.text && lhs.isActive == rhs.isActive && lhs.usesPlayerDarkTheme == rhs.usesPlayerDarkTheme
    }

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(isActive ? RavenDesign.Typography.transcriptActive() : RavenDesign.Typography.bodyUI())
                .foregroundStyle(lineColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, isActive ? 14 : 8)
        }
        .buttonStyle(.plain)
    }

    private var lineColor: Color {
        if usesPlayerDarkTheme {
            return isActive ? .white : .white.opacity(0.45)
        }
        return isActive ? Color.primary : Color.secondary.opacity(0.75)
    }
}

private struct PlayerCollapseHandle: View {
    let isCollapsed: Bool
    var usesPlayerDarkTheme: Bool
    let onSetCollapsed: (Bool) -> Void

    var body: some View {
        Capsule()
            .fill(usesPlayerDarkTheme ? .white.opacity(0.35) : Color.secondary.opacity(0.4))
            .frame(width: 32, height: 4)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .accessibilityLabel(isCollapsed ? "Expand player" : "Collapse player")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap, swipe down to expand, or swipe up to collapse")
            .onTapGesture {
                onSetCollapsed(!isCollapsed)
            }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        if value.translation.height > 20 {
                            onSetCollapsed(false)
                        } else if value.translation.height < -20 {
                            onSetCollapsed(true)
                        }
                    }
            )
    }
}

private struct TranscriptPlaceholderView<Actions: View>: View {
    let title: String
    let systemImage: String
    let message: String
    var footnote: String?
    var usesPlayerDarkTheme: Bool
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(usesPlayerDarkTheme ? .white.opacity(0.85) : Color.accentColor)

            VStack(spacing: 8) {
                Text(title)
                    .font(RavenDesign.Typography.headlineMedium())
                    .foregroundStyle(usesPlayerDarkTheme ? .white : .primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(RavenDesign.Typography.bodyUI())
                    .foregroundStyle(usesPlayerDarkTheme ? .white.opacity(0.65) : .secondary)
                    .multilineTextAlignment(.center)

                if let footnote {
                    Text(footnote)
                        .font(RavenDesign.Typography.labelCaps())
                        .foregroundStyle(usesPlayerDarkTheme ? .white.opacity(0.45) : Color.secondary.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)

            actions()

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct TranscriptPlaceholderButton: View {
    let title: String
    var usesPlayerDarkTheme: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RavenDesign.Typography.bodyUI().weight(.semibold))
                .foregroundStyle(usesPlayerDarkTheme ? RavenDesign.Colors.primary : RavenDesign.Colors.onPrimary)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    usesPlayerDarkTheme ? Color.white : RavenDesign.Colors.primary,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TranscriptLoadingView: View {
    let message: String
    var footnote: String?
    var usesPlayerDarkTheme = false

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(usesPlayerDarkTheme ? .white : .accentColor)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(usesPlayerDarkTheme ? .white.opacity(0.75) : .secondary)
                .multilineTextAlignment(.center)
            if let footnote {
                Text(footnote)
                    .font(RavenDesign.Typography.labelCaps())
                    .foregroundStyle(usesPlayerDarkTheme ? .white.opacity(0.45) : Color.secondary.opacity(0.75))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

enum TranscriptSegmentRowStyle {
    case card
    case lyrics
}

struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment
    let isActive: Bool
    var style: TranscriptSegmentRowStyle = .card
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            switch style {
            case .card:
                cardContent
            case .lyrics:
                lyricsContent
            }
        }
        .buttonStyle(.plain)
    }

    private var lyricsContent: some View {
        Text(segment.text)
            .font(isActive ? .title3.weight(.semibold) : .body)
            .foregroundStyle(isActive ? Color.primary : Color.secondary.opacity(0.75))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, isActive ? 14 : 8)
    }

    private var cardContent: some View {
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
