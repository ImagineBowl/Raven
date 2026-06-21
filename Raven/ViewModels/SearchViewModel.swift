//
//  SearchViewModel.swift
//  Raven
//
//  Created by Ahsan Minhas on 19/06/2026.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var bookResults: [Book] = []
    var transcriptResults: [TranscriptSearchHit] = []
    var isSearching = false
    var errorMessage: String?

    func performSearch(allBooks: [Book], modelContext: ModelContext) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        bookResults = LibrarySearchService.searchBooks(query: trimmed, in: allBooks)

        do {
            transcriptResults = try LibrarySearchService.searchTranscripts(
                query: trimmed,
                modelContext: modelContext
            )
        } catch {
            transcriptResults = []
            errorMessage = error.localizedDescription
        }
    }

    func clearResults() {
        bookResults = []
        transcriptResults = []
        errorMessage = nil
    }
}
