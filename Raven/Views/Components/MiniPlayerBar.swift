//
//  MiniPlayerBar.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI

struct MiniPlayerBar: View {
    let book: Book
    @Environment(AudioPlayerService.self) private var player
    var onExpand: () -> Void

    private var progress: Double {
        guard player.bookTotalDuration > 0 else { return 0 }
        return player.bookElapsedTime / player.bookTotalDuration
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExpand) {
                HStack(spacing: 12) {
                    BookArtworkView(book: book, cornerRadius: 4, contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .background(RavenDesign.Colors.surfaceContainer, in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(RavenDesign.Colors.onSurface)
                            .lineLimit(1)
                        Text(player.currentChapter?.title ?? book.author)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(RavenDesign.Colors.onSurface)
                }
                .buttonStyle(.plain)

                Button {
                    player.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                        .foregroundStyle(RavenDesign.Colors.onSurface)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RavenDesign.Colors.surfaceLowest)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(RavenDesign.Colors.outlineVariant.opacity(0.15), lineWidth: 1)
                }
        }
        .overlay(alignment: .bottom) {
            RavenProgressBar(progress: progress, height: 2)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }
}
