//
//  LibrarySearchService.swift
//  Raven
//
//  Created by Ahsan Minhas on 19/06/2026.
//

import Foundation
import SwiftData

struct TranscriptSearchHit: Identifiable {
    let id: UUID
    let book: Book
    let chapter: Chapter
    let segment: TranscriptSegment
    let snippet: String
}

enum LibrarySearchService {
    static func searchBooks(query: String, in books: [Book]) -> [Book] {
        let trimmed = normalizedQuery(query)
        guard !trimmed.isEmpty else { return [] }

        return books.filter { book in
            book.title.localizedCaseInsensitiveContains(trimmed)
                || book.author.localizedCaseInsensitiveContains(trimmed)
        }
    }

    static func searchTranscripts(query: String, modelContext: ModelContext) throws -> [TranscriptSearchHit] {
        let trimmed = normalizedQuery(query)
        guard !trimmed.isEmpty else { return [] }

        let descriptor = FetchDescriptor<TranscriptSegment>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let segments = try modelContext.fetch(descriptor)

        var hits: [TranscriptSearchHit] = []
        hits.reserveCapacity(min(segments.count, 100))

        for segment in segments {
            guard segment.text.localizedCaseInsensitiveContains(trimmed),
                  let chapter = segment.chapter,
                  let book = chapter.book,
                  chapter.hasTranscript else {
                continue
            }

            hits.append(
                TranscriptSearchHit(
                    id: segment.id,
                    book: book,
                    chapter: chapter,
                    segment: segment,
                    snippet: snippet(for: segment.text, matching: trimmed)
                )
            )

            if hits.count >= 100 {
                break
            }
        }

        return hits.sorted { lhs, rhs in
            let titleOrder = lhs.book.title.localizedStandardCompare(rhs.book.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            if lhs.chapter.sortOrder != rhs.chapter.sortOrder {
                return lhs.chapter.sortOrder < rhs.chapter.sortOrder
            }
            return lhs.segment.startTime < rhs.segment.startTime
        }
    }

    private static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func snippet(for text: String, matching query: String) -> String {
        let maxLength = 120
        guard text.count > maxLength else { return text }

        let loweredText = text.lowercased()
        let loweredQuery = query.lowercased()
        guard let range = loweredText.range(of: loweredQuery) else {
            return String(text.prefix(maxLength)) + "…"
        }

        let matchStart = text.distance(from: text.startIndex, to: range.lowerBound)
        let start = max(0, matchStart - 30)
        let end = min(text.count, start + maxLength)
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        var snippet = String(text[startIndex..<endIndex])
        if start > 0 { snippet = "…" + snippet }
        if end < text.count { snippet += "…" }
        return snippet
    }
}
