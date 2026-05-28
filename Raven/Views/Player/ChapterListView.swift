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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(book.sortedChapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        Task {
                            try? await player.playChapter(at: index)
                            player.play()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                Text(TimeFormatting.clock(chapter.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if chapter.hasTranscript {
                                Image(systemName: "text.quote")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if isCurrentChapter(index) {
                                Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                                    .foregroundStyle(currentChapterIndicatorColor)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func isCurrentChapter(_ index: Int) -> Bool {
        player.currentBook?.id == book.id && player.currentChapterIndex == index
    }

    private var currentChapterIndicatorColor: Color {
        colorScheme == .dark ? .primary : Color.accentColor
    }
}
