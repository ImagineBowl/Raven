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
    @State private var navigationPath = NavigationPath()
    @State private var visiblePlayerBookID: UUID?

    private var showMiniPlayer: Bool {
        guard let currentBook = player.currentBook else { return false }
        return visiblePlayerBookID != currentBook.id
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if books.isEmpty {
                    emptyLibraryView
                } else {
                    List {
                        ForEach(books) { book in
                            NavigationLink(value: book) {
                                BookRowView(book: book)
                            }
                        }
                        .onDelete(perform: deleteBooks)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    addFolderButton
                }
            }
            .navigationDestination(for: Book.self) { book in
                PlayerView(book: book)
                    .onAppear { visiblePlayerBookID = book.id }
                    .onDisappear {
                        if visiblePlayerBookID == book.id {
                            visiblePlayerBookID = nil
                        }
                    }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showMiniPlayer, let book = player.currentBook {
                    MiniPlayerBar(book: book) {
                        navigationPath.append(book)
                    }
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

    private var emptyLibraryView: some View {
        ContentUnavailableView {
            Label {
                Text("No Audiobooks")
            } icon: {
                RavenLogoView(size: 72)
            }
        } description: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add audiobooks using either method:")
                Text("1. Tap **Add Folder** in this app")
                Text("2. In the **Files** app go to:")
                Text(RavenLibraryStore.filesAppPathDescription)
                    .font(.callout.monospaced())
                Text("Then create a folder for each book and add your audio files.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } actions: {
            addFolderButton
        }
    }

    private var addFolderButton: some View {
        Button {
            viewModel.showDocumentPicker = true
        } label: {
            Label("Add Folder", systemImage: "folder.badge.plus")
        }
        .disabled(viewModel.isImporting || viewModel.isSyncing)
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            let book = books[index]
            BookDeletionService.delete(book, modelContext: modelContext, player: player)
        }
    }
}

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            BookArtworkView(book: book, cornerRadius: 8)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("\(book.sortedChapters.count) chapters")
                    Text("·")
                    Text(TimeFormatting.clock(book.totalDuration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !book.isAvailable {
                    Text("Folder missing from library")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                ProgressView(value: book.progressFraction)
                    .tint(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self, Chapter.self, TranscriptSegment.self], inMemory: true)
        .environment(AudioPlayerService())
        .environment(TranscriptionService())
}
