import SwiftUI

struct MiniPlayerBar: View {
    let book: Book
    @Environment(AudioPlayerService.self) private var player
    var onExpand: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExpand) {
                HStack(spacing: 12) {
                    BookArtworkView(book: book, cornerRadius: 6)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentChapter?.title ?? book.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(book.author.isEmpty ? book.title : book.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            BedtimeModeButton(style: .iconOnly)

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
