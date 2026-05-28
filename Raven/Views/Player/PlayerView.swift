import SwiftUI

struct PlayerView: View {
    let book: Book
    @Environment(AudioPlayerService.self) private var player
    @State private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                artwork
                metadata
                progressSection
                transportControls
                optionsRow
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let chapter = player.currentChapter {
                    Button {
                        viewModel.showTranscript = true
                    } label: {
                        Image(systemName: chapter.hasTranscript ? "text.quote" : "text.badge.plus")
                    }
                }
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
        .sheet(isPresented: $viewModel.showTranscript) {
            if let chapter = player.currentChapter {
                TranscriptView(book: book, chapter: chapter)
            }
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
        .onChange(of: player.bookElapsedTime) { _, _ in
            viewModel.bind(to: player)
        }
    }

    private var artwork: some View {
        BookArtworkView(book: book, cornerRadius: 16)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 280)
            .padding(.top, 8)
    }

    private var metadata: some View {
        VStack(spacing: 6) {
            Text(player.currentChapter?.title ?? book.title)
                .font(.title2.weight(.semibold))
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
                    .font(.title)
            }

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }

            Button {
                player.skipForward()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title)
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
