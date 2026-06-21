//
//  SearchView.swift
//  Raven
//
//  Created by Ahsan Minhas on 19/06/2026.
//

import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayerService.self) private var player
    @Query(sort: \Book.importedAt, order: .reverse) private var books: [Book]
    @State private var viewModel = SearchViewModel()
    @State private var presentedPlayerBook: Book?
    @State private var pendingTranscriptSeek: TimeInterval?

    private var hasResults: Bool {
        !viewModel.bookResults.isEmpty || !viewModel.transcriptResults.isEmpty
    }

    private var showEmptyQueryState: Bool {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if showEmptyQueryState {
                    emptyQueryView
                } else if viewModel.isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasResults {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .background(RavenDesign.Colors.paper.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                SearchScreenHeader()
            }
            .safeAreaInset(edge: .bottom, spacing: 8) {
                if let book = player.currentBook {
                    MiniPlayerBar(book: book) {
                        presentedPlayerBook = book
                    }
                    .padding(.bottom)
                    .padding(.horizontal, RavenDesign.Spacing.pageMargin)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $viewModel.query, prompt: "Books, authors, or transcript text")
            .fullScreenCover(isPresented: playerCoverIsPresented, onDismiss: {
                pendingTranscriptSeek = nil
            }) {
                if let presentedPlayerBook {
                    PlayerView(book: presentedPlayerBook)
                        .task(id: pendingTranscriptSeek) {
                            guard let seekTime = pendingTranscriptSeek else { return }
                            player.seek(to: seekTime)
                            pendingTranscriptSeek = nil
                        }
                }
            }
            .alert("Search Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task(id: viewModel.query) {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await viewModel.performSearch(allBooks: books, modelContext: modelContext)
            }
        }
    }

    private var emptyQueryView: some View {
        ContentUnavailableView {
            Label("Search Raven", systemImage: "magnifyingglass")
        } description: {
            Text("Find audiobooks by title or author, or search words inside generated transcripts.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        ContentUnavailableView.search(text: viewModel.query)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RavenDesign.Spacing.stackLarge) {
                if !viewModel.bookResults.isEmpty {
                    resultsSection(title: "Books") {
                        RavenLibraryCard {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.bookResults.enumerated()), id: \.element.id) { index, book in
                                    Button {
                                        openBook(book)
                                    } label: {
                                        CompactBookRow(book: book)
                                    }
                                    .buttonStyle(.plain)

                                    if index < viewModel.bookResults.count - 1 {
                                        RavenDesign.Colors.outlineVariant.opacity(1)
                                            .frame(height: 1)
                                            .padding(.leading, RavenDesign.BookCover.compactSize + RavenDesign.Spacing.stackMedium)
                                    }
                                }
                            }
                        }
                    }
                }

                if !viewModel.transcriptResults.isEmpty {
                    resultsSection(title: "Transcripts") {
                        RavenLibraryCard {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.transcriptResults.enumerated()), id: \.element.id) { index, hit in
                                    Button {
                                        openTranscriptHit(hit)
                                    } label: {
                                        TranscriptSearchResultRow(hit: hit)
                                    }
                                    .buttonStyle(.plain)

                                    if index < viewModel.transcriptResults.count - 1 {
                                        RavenDesign.Colors.outlineVariant.opacity(1)
                                            .frame(height: 1)
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, RavenDesign.Spacing.pageMargin)
            .padding(.top, RavenDesign.Spacing.stackMedium)
            .padding(.bottom, player.currentBook == nil ? 32 : 96)
        }
        .scrollIndicators(.hidden)
    }

    private func resultsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RavenDesign.Spacing.stackSmall) {
            Text(title)
                .font(RavenDesign.Typography.labelCaps())
                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 4)

            content()
        }
    }

    private func openBook(_ book: Book) {
        pendingTranscriptSeek = nil
        presentedPlayerBook = book
    }

    private func openTranscriptHit(_ hit: TranscriptSearchHit) {
        pendingTranscriptSeek = hit.segment.startTime
        presentedPlayerBook = hit.book

        Task {
            if player.currentBook?.id != hit.book.id {
                try? await player.load(hit.book, autoPlay: false)
            }
            if let chapterIndex = hit.book.sortedChapters.firstIndex(where: { $0.id == hit.chapter.id }) {
                try? await player.playChapter(at: chapterIndex)
            }
            player.seek(to: hit.segment.startTime)
        }
    }

    private var playerCoverIsPresented: Binding<Bool> {
        Binding(
            get: { presentedPlayerBook != nil },
            set: { isPresented in
                if !isPresented {
                    presentedPlayerBook = nil
                    pendingTranscriptSeek = nil
                }
            }
        )
    }
}

private struct SearchScreenHeader: View {
    var body: some View {
        Text("Search")
            .font(RavenDesign.Typography.displayLarge())
            .foregroundStyle(RavenDesign.Colors.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RavenDesign.Spacing.pageMargin)
            .padding(.bottom, RavenDesign.Spacing.stackMedium)
            .padding(.top, 4)
            .background {
                Rectangle()
                    .fill(RavenDesign.Colors.paper)
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) {
                        RavenDesign.Colors.outlineVariant.opacity(0.2)
                            .frame(height: 1)
                    }
            }
    }
}

private struct TranscriptSearchResultRow: View {
    let hit: TranscriptSearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hit.book.title)
                .font(RavenDesign.Typography.bodyUI().weight(.semibold))
                .foregroundStyle(RavenDesign.Colors.onSurface)
                .lineLimit(1)

            Text(hit.chapter.title)
                .font(RavenDesign.Typography.labelCaps())
                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)

            Text(hit.snippet)
                .font(RavenDesign.Typography.bodyUI())
                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Text(TimeFormatting.clock(hit.segment.startTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(RavenDesign.Colors.onSurfaceVariant.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [Book.self, Chapter.self, TranscriptSegment.self], inMemory: true)
        .environment(AudioPlayerService())
}
