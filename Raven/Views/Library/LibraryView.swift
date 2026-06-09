//
//  LibraryView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AudioPlayerService.self) private var player
    @Query(sort: \Book.importedAt, order: .reverse) private var books: [Book]
    @State private var viewModel = LibraryViewModel()
    @State private var visiblePlayerBookID: UUID?
    @State private var presentedPlayerBook: Book?

    private var showMiniPlayer: Bool {
        guard let currentBook = player.currentBook else { return false }
        return visiblePlayerBookID != currentBook.id
    }

    private var featuredBook: Book? {
        if let current = player.currentBook, books.contains(where: { $0.id == current.id }) {
            return current
        }
        return books.first
    }

    private var otherBooks: [Book] {
        guard let featuredBook else { return books }
        return books.filter { $0.id != featuredBook.id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    VStack(spacing: 0) {
                        LibraryScreenHeader()
                        EmptyLibraryView(
                            isAddDisabled: viewModel.isImporting || viewModel.isSyncing,
                            onAddFolder: { viewModel.showDocumentPicker = true }
                        )
                    }
                } else {
                    populatedLibraryView
                }
            }
            .background(RavenDesign.Colors.paper)
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: playerCoverIsPresented) {
                if let presentedPlayerBook {
                    PlayerView(book: presentedPlayerBook)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 8) {
                if showMiniPlayer, let book = player.currentBook {
                    MiniPlayerBar(book: book) {
                        presentPlayer(book)
                    }
                    .padding(.bottom)
                    .padding(.horizontal, RavenDesign.Spacing.pageMargin)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showMiniPlayer)
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                FolderDocumentPicker(
                    onPick: { url in
                        viewModel.showDocumentPicker = false
                        Task {
                            await viewModel.addFolderToLibrary(
                                url: url,
                                modelContext: modelContext,
                                player: player
                            )
                        }
                    },
                    onCancel: {
                        viewModel.showDocumentPicker = false
                    }
                )
            }
            .overlay {
                if viewModel.isImporting || viewModel.isSyncing {
                    ProgressView(viewModel.isImporting ? "Adding to library…" : "Scanning library…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Library Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                player.configure(modelContext: modelContext)
                await viewModel.syncLibrary(modelContext: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.syncLibrary(modelContext: modelContext) }
                }
            }
        }
    }

    private var populatedLibraryView: some View {
        VStack(spacing: 0) {
            LibraryScreenHeader(
                onAddFolder: { viewModel.showDocumentPicker = true },
                isAddDisabled: viewModel.isImporting || viewModel.isSyncing
            )

            ScrollView {
                VStack(spacing: RavenDesign.Spacing.stackLarge) {
                    if let featuredBook {
                        Button {
                            presentPlayer(featuredBook)
                        } label: {
                            RavenLibraryCard {
                                FeaturedBookRow(
                                    book: featuredBook,
                                    progress: progress(for: featuredBook)
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contextMenu {
                            deleteContextMenu(for: featuredBook)
                        }
                    }

                    if !otherBooks.isEmpty {
                        RavenLibraryCard {
                            VStack(spacing: 0) {
                                ForEach(Array(otherBooks.enumerated()), id: \.element.id) { index, book in
                                    Button {
                                        presentPlayer(book)
                                    } label: {
                                        CompactBookRow(book: book)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        deleteContextMenu(for: book)
                                    }

                                    if index < otherBooks.count - 1 {
                                        RavenDesign.Colors.outlineVariant.opacity(1)
                                            .frame(height: 1)
                                            .padding(.leading, RavenDesign.BookCover.compactSize + RavenDesign.Spacing.stackMedium)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, RavenDesign.Spacing.pageMargin)
                .padding(.top, RavenDesign.Spacing.stackMedium)
                .padding(.bottom, showMiniPlayer ? 96 : 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func progress(for book: Book) -> Double {
        if player.currentBook?.id == book.id, player.bookTotalDuration > 0 {
            return player.bookElapsedTime / player.bookTotalDuration
        }
        return book.progressFraction
    }

    private var playerCoverIsPresented: Binding<Bool> {
        Binding(
            get: { presentedPlayerBook != nil },
            set: { isPresented in
                if !isPresented {
                    presentedPlayerBook = nil
                    visiblePlayerBookID = nil
                }
            }
        )
    }

    private func presentPlayer(_ book: Book) {
        presentedPlayerBook = book
        visiblePlayerBookID = book.id
    }

    @ViewBuilder
    private func deleteContextMenu(for book: Book) -> some View {
        Button(role: .destructive) {
            BookDeletionService.delete(book, modelContext: modelContext, player: player)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self, Chapter.self, TranscriptSegment.self], inMemory: true)
        .environment(AudioPlayerService())
        .environment(TranscriptionService())
}
