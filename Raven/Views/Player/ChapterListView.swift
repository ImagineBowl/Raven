import SwiftUI

struct ChapterListView: View {
    let book: Book
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

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
                                    .foregroundStyle(.primary)
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
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
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
}
