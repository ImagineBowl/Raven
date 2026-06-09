//
//  ChapterListView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI

struct ChapterListView: View {
    let book: Book
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(book.sortedChapters.enumerated()), id: \.element.id) { index, chapter in
                        ChapterListRow(
                            chapter: chapter,
                            chapterNumber: index + 1,
                            isCurrentChapter: isCurrentChapter(index),
                            isPlaying: player.isPlaying && isCurrentChapter(index),
                            chapterRemaining: isCurrentChapter(index)
                                ? max(0, chapter.duration - player.currentTime)
                                : nil,
                            onSelect: {
                                Task {
                                    try? await player.playChapter(at: index)
                                    player.play()
                                }
                            }
                        )

                        if index < book.sortedChapters.count - 1 {
                            Divider()
                                .overlay(RavenDesign.Colors.outlineVariant.opacity(0.1))
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(RavenDesign.Colors.surfaceLowest.opacity(0.4))
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, RavenDesign.Spacing.pageMargin)
                .padding(.bottom, RavenDesign.Spacing.stackMedium)
            }

            chapterSheetMiniPlayer
        }
        .background(RavenDesign.Colors.secondaryContainer)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(40)
    }

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(RavenDesign.Colors.onSurfaceVariant.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            HStack {
                Text("Chapters")
                    .font(RavenDesign.Typography.headlineMedium())
                    .foregroundStyle(RavenDesign.Colors.onSurface)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .background(
                            RavenDesign.Colors.surfaceContainerHighest.opacity(0.5),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, RavenDesign.Spacing.pageMargin)
            .padding(.bottom, RavenDesign.Spacing.stackMedium)
        }
    }

    private var chapterSheetMiniPlayer: some View {
        HStack(spacing: 16) {
            BookArtworkView(book: book, cornerRadius: 8, contentMode: .fit)
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentChapter?.title ?? book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RavenDesign.Colors.onSurface)
                    .lineLimit(1)

                Text(chapterSheetSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button {
                    player.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundStyle(RavenDesign.Colors.primary)
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(RavenDesign.Colors.primary)
                }
                .buttonStyle(.plain)

                Button {
                    player.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                        .foregroundStyle(RavenDesign.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, RavenDesign.Spacing.pageMargin)
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    RavenDesign.Colors.outlineVariant.opacity(0.2)
                        .frame(height: 1)
                }
        }
    }

    private var chapterSheetSubtitle: String {
        guard player.currentBook?.id == book.id else {
            return book.title
        }
        let number = player.currentChapterIndex + 1
        return "\(book.title) — Chapter \(number)"
    }

    private func isCurrentChapter(_ index: Int) -> Bool {
        player.currentBook?.id == book.id && player.currentChapterIndex == index
    }
}

private struct ChapterListRow: View {
    let chapter: Chapter
    let chapterNumber: Int
    let isCurrentChapter: Bool
    let isPlaying: Bool
    let chapterRemaining: TimeInterval?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
                if isCurrentChapter {
                    Rectangle()
                        .fill(RavenDesign.Colors.primary)
                        .frame(width: 4)
                        .padding(.vertical, -RavenDesign.Spacing.stackMedium)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if isCurrentChapter {
                        HStack(spacing: 8) {
                            Text("Chapter \(chapterNumber)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(RavenDesign.Colors.onSurface)

                            if isPlaying {
                                ChapterPlayingBars()
                            }
                        }

                        Text(chapter.title)
                            .font(RavenDesign.Typography.headlineMedium())
                            .foregroundStyle(RavenDesign.Colors.onSurface)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("Chapter \(chapterNumber)")
                            .font(.system(size: 12))
                            .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.7))

                        Text(chapter.title)
                            .font(RavenDesign.Typography.bodyUI())
                            .foregroundStyle(RavenDesign.Colors.onSurface)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isCurrentChapter {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Playing")
                            .font(RavenDesign.Typography.labelCaps())
                            .foregroundStyle(RavenDesign.Colors.primary)

                        if let chapterRemaining {
                            Text("\(TimeFormatting.clock(chapterRemaining)) remaining")
                                .font(.system(size: 10))
                                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                        }
                    }
                } else {
                    Text(TimeFormatting.clock(chapter.duration))
                        .font(RavenDesign.Typography.labelCaps())
                        .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.5))
                }
            }
            .padding(RavenDesign.Spacing.stackMedium)
            .background {
                if isCurrentChapter {
                    RavenDesign.Colors.primaryContainer.opacity(0.05)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ChapterPlayingBars: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(RavenDesign.Colors.primary)
                    .frame(width: 2, height: animating ? barHeight(for: index) : 4)
                    .animation(
                        .easeInOut(duration: barDuration(for: index))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.12),
                        value: animating
                    )
            }
        }
        .frame(height: 12)
        .onAppear { animating = true }
    }

    private func barHeight(for index: Int) -> CGFloat {
        switch index {
        case 0: 10
        case 1: 12
        default: 8
        }
    }

    private func barDuration(for index: Int) -> Double {
        switch index {
        case 0: 1.0
        case 1: 1.2
        default: 0.8
        }
    }
}
