import SwiftUI

/// Applies scroll-offset hysteresis so collapse state does not thrash while scrolling.
struct PlayerCollapseState {
    private(set) var isCollapsed = false

    mutating func update(for offset: CGFloat) -> Bool {
        if !isCollapsed, offset > 48 {
            isCollapsed = true
            return true
        }
        if isCollapsed, offset < 8 {
            isCollapsed = false
            return true
        }
        return false
    }

    mutating func reset() {
        isCollapsed = false
    }
}

struct PlayerView: View {
    let book: Book
    @Environment(AudioPlayerService.self) private var player
    @State private var viewModel = PlayerViewModel()
    @State private var collapseState = PlayerCollapseState()

    var body: some View {
        VStack(spacing: 0) {
            playerHeader
                .animation(.easeInOut(duration: 0.25), value: collapseState.isCollapsed)

            Divider()

            if let chapter = player.currentChapter {
                TranscriptPanel(
                    book: book,
                    chapter: chapter,
                    onScrollOffsetChange: { offset in
                        var next = collapseState
                        if next.update(for: offset) {
                            collapseState = next
                        }
                    }
                )
            } else {
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showChapterList = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
        .sheet(isPresented: $viewModel.showChapterList) {
            ChapterListView(book: book)
        }
        .task(id: book.id) {
            if player.currentBook?.id != book.id {
                try? await player.load(book, autoPlay: false)
            }
        }
        .onChange(of: player.currentChapter?.id) { _, _ in
            collapseState = PlayerCollapseState()
        }
    }

    @ViewBuilder
    private var playerHeader: some View {
        if collapseState.isCollapsed {
            collapsedPlayerBar
        } else {
            expandedPlayerContent
        }
    }

    private var expandedPlayerContent: some View {
        VStack(spacing: 20) {
            artwork
            metadata
            PlayerProgressSection(viewModel: viewModel)
            transportControls
            optionsRow
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var collapsedPlayerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                BookArtworkView(book: book, cornerRadius: 6)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentChapter?.title ?? book.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    PlayerElapsedLabel()
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                BedtimeModeButton(style: .iconOnly)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            PlayerProgressSection(viewModel: viewModel, controlSize: .mini)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var artwork: some View {
        BookArtworkView(book: book, cornerRadius: 16)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 220)
    }

    private var metadata: some View {
        VStack(spacing: 6) {
            Text(player.currentChapter?.title ?? book.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(book.author.isEmpty ? book.title : book.author)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button {
                player.skipBackward()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }

            Button {
                player.skipForward()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title2)
            }
        }
        .buttonStyle(.plain)
    }

    private var optionsRow: some View {
        HStack {
            Menu {
                ForEach(viewModel.playbackRates, id: \.self) { rate in
                    Button {
                        player.setPlaybackRate(rate)
                    } label: {
                        if player.playbackRate == rate {
                            Label("\(rate, specifier: "%.2g")×", systemImage: "checkmark")
                        } else {
                            Text("\(rate, specifier: "%.2g")×")
                        }
                    }
                }
            } label: {
                Label("\(player.playbackRate, specifier: "%.2g")×", systemImage: "gauge.with.dots.needle.33percent")
                    .font(.subheadline)
            }

            Spacer()

            BedtimeModeButton()
        }
        .foregroundStyle(.primary)
    }
}

/// Isolates playback slider updates so transcript scrolling is not invalidated every tick.
private struct PlayerProgressSection: View {
    @Environment(AudioPlayerService.self) private var player
    @Bindable var viewModel: PlayerViewModel
    var controlSize: ControlSize = .regular

    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: $viewModel.scrubValue,
                in: 0...max(player.bookTotalDuration, 1),
                onEditingChanged: { editing in
                    if editing {
                        viewModel.beginScrubbing(player: player)
                    } else {
                        viewModel.endScrubbing(player: player)
                    }
                }
            )
            .controlSize(controlSize)

            HStack {
                Text(TimeFormatting.clock(viewModel.isScrubbing ? viewModel.scrubValue : player.bookElapsedTime))
                Spacer()
                Text(TimeFormatting.remaining(
                    viewModel.isScrubbing ? viewModel.scrubValue : player.bookElapsedTime,
                    total: player.bookTotalDuration
                ))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .onChange(of: player.bookElapsedTime) { _, _ in
            viewModel.bind(to: player)
        }
    }
}

/// Compact elapsed/remaining label for the collapsed player bar.
private struct PlayerElapsedLabel: View {
    @Environment(AudioPlayerService.self) private var player

    var body: some View {
        Text(
            "\(TimeFormatting.clock(player.bookElapsedTime)) · \(TimeFormatting.remaining(player.bookElapsedTime, total: player.bookTotalDuration))"
        )
    }
}
