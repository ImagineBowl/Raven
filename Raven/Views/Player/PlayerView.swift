import SwiftUI

struct PlayerView: View {
    let book: Book
    @Environment(AudioPlayerService.self) private var player
    @State private var viewModel = PlayerViewModel()
    @State private var isPlayerCollapsed = false

    var body: some View {
        VStack(spacing: 0) {
            playerHeader

            Divider()

            if let chapter = player.currentChapter {
                TranscriptPanel(
                    book: book,
                    chapter: chapter,
                    onScrollOffsetChange: { offset in
                        let shouldCollapse = offset > 20
                        guard shouldCollapse != isPlayerCollapsed else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isPlayerCollapsed = shouldCollapse
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
        .confirmationDialog("Sleep Timer", isPresented: $viewModel.showSleepTimer) {
            ForEach(viewModel.sleepTimerOptions, id: \.self) { minutes in
                Button(viewModel.sleepTimerLabel(for: minutes)) {
                    player.setSleepTimer(minutes: minutes)
                }
            }
        }
        .task(id: book.id) {
            if player.currentBook?.id != book.id {
                try? await player.load(book, autoPlay: false)
            }
        }
        .onChange(of: player.currentChapter?.id) { _, _ in
            isPlayerCollapsed = false
        }
        .onChange(of: player.bookElapsedTime) { _, _ in
            viewModel.bind(to: player)
        }
    }

    @ViewBuilder
    private var playerHeader: some View {
        if isPlayerCollapsed {
            collapsedPlayerBar
        } else {
            expandedPlayerContent
        }
    }

    private var expandedPlayerContent: some View {
        VStack(spacing: 20) {
            artwork
            metadata
            progressSection
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

                    Text(
                        "\(TimeFormatting.clock(player.bookElapsedTime)) · \(TimeFormatting.remaining(player.bookElapsedTime, total: player.bookTotalDuration))"
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

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
            .controlSize(.mini)
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

    private var progressSection: some View {
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

            Button {
                viewModel.showSleepTimer = true
            } label: {
                Label(
                    player.sleepTimerEndDate == nil ? "Timer" : "Timer On",
                    systemImage: "moon.zzz"
                )
                .font(.subheadline)
            }
        }
        .foregroundStyle(.primary)
    }
}
