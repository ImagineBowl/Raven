//
//  PlayerView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI

/// Applies scroll-offset hysteresis so collapse state does not thrash while scrolling.
struct PlayerCollapseState {
    private(set) var isCollapsed = false
    private var keepsExpanded = false
    private var keepsCollapsed = false

    mutating func expandManually() {
        isCollapsed = false
        keepsExpanded = true
        keepsCollapsed = false
    }

    mutating func collapseManually() {
        isCollapsed = true
        keepsCollapsed = true
        keepsExpanded = false
    }

    mutating func update(for offset: CGFloat) -> Bool {
        if keepsCollapsed {
            return false
        }

        if keepsExpanded {
            if offset < 8 {
                keepsExpanded = false
            } else {
                return false
            }
        }

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
        keepsExpanded = false
        keepsCollapsed = false
    }
}

struct PlayerView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var player
    @State private var viewModel = PlayerViewModel()
    @State private var collapseState = PlayerCollapseState()
    @State private var showChapterList = false

    private static let collapseAnimation = Animation.spring(response: 0.38, dampingFraction: 0.86)

    var body: some View {
        VStack(spacing: 0) {
            playerNavigationBar

            playerHeader
                .clipped()

            Divider()
                .overlay(RavenDesign.Colors.outlineVariant.opacity(0.2))

            if let chapter = player.currentChapter {
                TranscriptPanel(
                    book: book,
                    chapter: chapter,
                    isPlayerCollapsed: collapseState.isCollapsed,
                    onPlayerCollapseChange: setPlayerCollapsed,
                    onScrollOffsetChange: { offset in
                        var next = collapseState
                        if next.update(for: offset) {
                            withAnimation(Self.collapseAnimation) {
                                collapseState = next
                            }
                        }
                    },
                    usesPlayerDarkTheme: true
                )
            } else {
                Spacer()
            }
        }
        .background {
            RavenDesign.Colors.playerSurface
                .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showChapterList) {
            ChapterListView(book: book)
        }
        .task(id: book.id) {
            if player.currentBook?.id != book.id {
                try? await player.load(book, autoPlay: false)
            }
        }
        .onChange(of: player.currentChapter?.id) { _, _ in
            withAnimation(Self.collapseAnimation) {
                collapseState = PlayerCollapseState()
            }
        }
    }

    private func setPlayerCollapsed(_ collapsed: Bool) {
        if collapsed {
            guard !collapseState.isCollapsed else { return }
            var next = collapseState
            next.collapseManually()
            withAnimation(Self.collapseAnimation) {
                collapseState = next
            }
        } else {
            guard collapseState.isCollapsed else { return }
            var next = collapseState
            next.expandManually()
            withAnimation(Self.collapseAnimation) {
                collapseState = next
            }
        }
    }

    @ViewBuilder
    private var playerHeader: some View {
        Group {
            if collapseState.isCollapsed {
                collapsedPlayerBar
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        )
                    )
            } else {
                expandedPlayerContent
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                        )
                    )
            }
        }
        .animation(Self.collapseAnimation, value: collapseState.isCollapsed)
    }

    private var playerNavigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 4) {
                Text("Now Playing")
                    .font(RavenDesign.Typography.headlineMedium())
                    .foregroundStyle(.white)

                Text(chapterSubtitle)
                    .font(RavenDesign.Typography.labelCaps())
                    .foregroundStyle(.white.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button("Chapters") {
                    showChapterList = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, RavenDesign.Spacing.pageMargin)
        .padding(.top, 8)
        .padding(.bottom, RavenDesign.Spacing.stackSmall)
    }

    private var chapterSubtitle: String {
        player.currentChapter?.title ?? book.title
    }

    private var expandedPlayerContent: some View {
        VStack(spacing: 16) {
            artworkSection
            metadataSection
            controlsSection
        }
        .padding(.horizontal, RavenDesign.Spacing.pageMargin)
        .padding(.bottom, 12)
    }

    private var collapsedPlayerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                BookArtworkView(book: book, cornerRadius: 6, contentMode: .fit)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentChapter?.title ?? book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    PlayerElapsedLabel()
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 8)

                PlayerBedtimeButton()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            PlayerProgressSection(viewModel: viewModel, controlSize: .mini)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RavenDesign.Colors.playerSurface)
    }

    private var artworkSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.black.opacity(0.35))
                .blur(radius: 20)
                .scaleEffect(0.92)
                .offset(y: 16)

            BookArtworkView(book: book, cornerRadius: 8, contentMode: .fit)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 220)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        }
    }

    private var metadataSection: some View {
        VStack(spacing: 4) {
            Text(book.title)
                .font(RavenDesign.Typography.headlineMedium())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(book.author.isEmpty ? book.title : book.author)
                .font(RavenDesign.Typography.bodyUI())
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }

    private var controlsSection: some View {
        VStack(spacing: RavenDesign.Spacing.stackMedium) {
            PlayerProgressSection(viewModel: viewModel)

            HStack {
                playbackSpeedButton
                    .frame(width: 48, height: 48)

                Spacer()

                HStack(spacing: 28) {
                    skipButton(systemImage: "gobackward.15") {
                        player.skipBackward()
                    }

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(RavenDesign.Colors.primary)
                            .frame(width: 72, height: 72)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    }
                    .buttonStyle(RavenPressButtonStyle())

                    skipButton(systemImage: "goforward.30") {
                        player.skipForward()
                    }
                }

                Spacer()

                PlayerBedtimeButton()
                    .frame(width: 48, height: 48)
            }
        }
    }

    private var playbackSpeedButton: some View {
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
            Text("\(player.playbackRate, specifier: "%.2g")×")
                .font(RavenDesign.Typography.labelCaps())
                .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    private func skipButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(RavenPressButtonStyle())
    }
}

private struct PlayerProgressSection: View {
    @Environment(AudioPlayerService.self) private var player
    @Bindable var viewModel: PlayerViewModel
    var controlSize: ControlSize = .regular

    var body: some View {
        VStack(spacing: RavenDesign.Spacing.stackSmall) {
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
            .tint(.white)

            HStack {
                Text(TimeFormatting.clock(viewModel.isScrubbing ? viewModel.scrubValue : player.bookElapsedTime))
                Spacer()
                Text(TimeFormatting.remaining(
                    viewModel.isScrubbing ? viewModel.scrubValue : player.bookElapsedTime,
                    total: player.bookTotalDuration
                ))
            }
            .font(RavenDesign.Typography.labelCaps())
            .foregroundStyle(.white.opacity(0.4))
            .monospacedDigit()
        }
        .onChange(of: player.bookElapsedTime) { _, _ in
            viewModel.bind(to: player)
        }
    }
}

private struct PlayerElapsedLabel: View {
    @Environment(AudioPlayerService.self) private var player

    var body: some View {
        Text(
            "\(TimeFormatting.clock(player.bookElapsedTime)) · \(TimeFormatting.remaining(player.bookElapsedTime, total: player.bookTotalDuration))"
        )
    }
}

private struct PlayerBedtimeButton: View {
    @Environment(AudioPlayerService.self) private var player

    var body: some View {
        Button {
            player.toggleBedtimeMode()
        } label: {
            Image(systemName: "moon.fill")
                .font(.title3)
                .foregroundStyle(
                    player.isBedtimeModeEnabled
                        ? RavenDesign.Colors.primaryFixedDim
                        : .white.opacity(0.8)
                )
                .frame(width: 36, height: 36)
                .background {
                    if player.isBedtimeModeEnabled {
                        Circle().fill(.white.opacity(0.1))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bedtime mode")
    }
}

#Preview {
    PlayerView(book: Book(title: "The Name of the Wind", author: "Patrick Rothfuss"))
        .environment(AudioPlayerService())
        .environment(TranscriptionService())
}
