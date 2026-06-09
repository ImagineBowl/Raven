//
//  LibraryBookRows.swift
//  Raven
//
//  Created by Ahsan Minhas on 29/05/2026.
//

import SwiftUI

private struct LibraryBookCover: View {
    let book: Book
    let size: CGFloat

    var body: some View {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(.clear)
        .frame(width: size, height: size)
        .overlay {
          BookArtworkView(book: book, cornerRadius: 4, contentMode: .fit)
            .padding(2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct FeaturedBookRow: View {
    let book: Book
    let progress: Double

    var body: some View {
        HStack(alignment: .top, spacing: RavenDesign.Spacing.stackMedium) {
            LibraryBookCover(book: book, size: RavenDesign.BookCover.featuredSize)

            VStack(alignment: .leading, spacing: RavenDesign.Spacing.stackSmall) {
                Text(book.title)
                    .font(RavenDesign.Typography.headlineMedium())
                    .foregroundStyle(RavenDesign.Colors.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(RavenDesign.Typography.bodyUI())
                        .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                }

                HStack(spacing: 8) {
                    Text("\(book.sortedChapters.count) chapters")
                        .font(RavenDesign.Typography.labelCaps())
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Circle()
                        .fill(RavenDesign.Colors.outlineVariant)
                        .frame(width: 4, height: 4)
                    Text(TimeFormatting.durationCompact(book.totalDuration))
                        .font(RavenDesign.Typography.labelCaps())
                }
                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.7))
                .padding(.top, 4)

                if !book.isAvailable {
                    Text("Folder missing from library")
                        .font(RavenDesign.Typography.labelCaps())
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    RavenProgressBar(progress: progress)
                    Text("\(Int(progress * 100))% Completed")
                        .font(RavenDesign.Typography.labelCaps())
                        .foregroundStyle(RavenDesign.Colors.primary)
                }
                .padding(.top, RavenDesign.Spacing.stackMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}

struct CompactBookRow: View {
    let book: Book

    private var remainingDuration: TimeInterval {
        max(0, book.totalDuration * (1 - book.progressFraction))
    }

    var body: some View {
        HStack(alignment: .center, spacing: RavenDesign.Spacing.stackMedium) {
            LibraryBookCover(book: book, size: RavenDesign.BookCover.compactSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(RavenDesign.Colors.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.author.isEmpty ? "Unknown Author" : book.author)
                    .font(RavenDesign.Typography.labelCaps())
                    .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)

                Text("\(TimeFormatting.durationCompact(remainingDuration)) remaining")
                    .font(RavenDesign.Typography.labelCaps())
                    .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.6))

                if !book.isAvailable {
                    Text("Folder missing")
                        .font(RavenDesign.Typography.labelCaps())
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
