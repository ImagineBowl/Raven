import Foundation
import SwiftData

@MainActor
final class BookImportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Scans library folders and imports or relinks any audiobooks found on disk.
    @discardableResult
    func syncLibrary() async throws -> Int {
        let folders = try RavenLibraryStore.audiobookFolders()
        var addedCount = 0

        for folderURL in folders {
            let folderName = folderURL.lastPathComponent
            let scanResult = try await BookScanner.scan(folderURL: folderURL)

            if let existing = try findLibraryBook(named: folderName) {
                try await refreshBookIfNeeded(existing, scanResult: scanResult)
            } else if let linked = try findBook(matching: scanResult.contentFingerprint) {
                link(linked, folderName: folderName, scanResult: scanResult)
            } else {
                _ = try createBook(from: scanResult, folderName: folderName)
                addedCount += 1
            }
        }

        try modelContext.save()
        return addedCount
    }

    /// Copies a picked folder into `Documents/Raven`, then imports it.
    func addFolderToLibrary(from sourceURL: URL) async throws -> Book {
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try RavenLibraryStore.ensureExists()
        let destination = RavenLibraryStore.uniqueDestinationURL(for: sourceURL.lastPathComponent)

        if sourceURL.hasDirectoryPath {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } else {
            throw ImportError.notAFolder
        }

        let folderName = destination.lastPathComponent
        let scanResult = try await BookScanner.scan(folderURL: destination)

        if let existing = try findLibraryBook(named: folderName) {
            try modelContext.save()
            return existing
        }
        if let linked = try findBook(matching: scanResult.contentFingerprint) {
            link(linked, folderName: folderName, scanResult: scanResult)
            try modelContext.save()
            return linked
        }

        let book = try createBook(from: scanResult, folderName: folderName)
        try modelContext.save()
        return book
    }

    // MARK: - Private

    private func createBook(from scanResult: ScanResult, folderName: String) throws -> Book {
        let book = Book(
            title: scanResult.title,
            author: scanResult.author,
            folderName: folderName,
            source: .library,
            artworkData: scanResult.artworkData,
            contentFingerprint: scanResult.contentFingerprint
        )
        applyChapters(from: scanResult, to: book)
        modelContext.insert(book)
        return book
    }

    private func link(_ book: Book, folderName: String, scanResult: ScanResult) {
        book.folderName = folderName
        book.source = .library
        book.title = scanResult.title
        book.author = scanResult.author
        book.artworkData = scanResult.artworkData ?? book.artworkData
        book.contentFingerprint = scanResult.contentFingerprint
    }

    private func refreshBookIfNeeded(_ book: Book, scanResult: ScanResult) throws {
        let scannedPaths = BookFingerprint.makePathIdentity(from: scanResult.chapters)
        let savedPaths = BookFingerprint.makePathIdentity(from: book)
        guard scannedPaths != savedPaths else {
            // Still refresh metadata without touching playback state.
            book.title = scanResult.title
            book.author = scanResult.author
            if book.artworkData == nil {
                book.artworkData = scanResult.artworkData
            }
            return
        }

        let savedChapterPath = book.sortedChapters[safe: book.currentChapterIndex]?.relativePath
        let savedTime = book.currentTime

        book.title = scanResult.title
        book.author = scanResult.author
        book.artworkData = scanResult.artworkData ?? book.artworkData
        book.contentFingerprint = scanResult.contentFingerprint

        book.chapters.forEach { modelContext.delete($0) }
        applyChapters(from: scanResult, to: book)

        if let savedChapterPath,
           let newIndex = book.sortedChapters.firstIndex(where: { $0.relativePath == savedChapterPath }) {
            book.currentChapterIndex = newIndex
            book.currentTime = min(savedTime, book.sortedChapters[newIndex].duration)
        } else {
            book.currentChapterIndex = min(book.currentChapterIndex, max(0, book.sortedChapters.count - 1))
            book.currentTime = min(savedTime, book.sortedChapters[safe: book.currentChapterIndex]?.duration ?? savedTime)
        }

        book.recalculateTotalDuration()
    }

    private func applyChapters(from scanResult: ScanResult, to book: Book) {
        book.chapters = scanResult.chapters.map { scanned in
            Chapter(
                title: scanned.title,
                relativePath: scanned.relativePath,
                duration: scanned.duration,
                sortOrder: scanned.sortOrder
            )
        }
        book.recalculateTotalDuration()
    }

    private func findLibraryBook(named folderName: String) throws -> Book? {
        let name = folderName
        let source = BookSource.library.rawValue
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.folderName == name && $0.sourceTypeRaw == source }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func findBook(matching fingerprint: String) throws -> Book? {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.contentFingerprint == fingerprint }
        )
        return try modelContext.fetch(descriptor).first
    }
}

enum ImportError: LocalizedError {
    case duplicateBook(existingTitle: String)
    case notAFolder

    var errorDescription: String? {
        switch self {
        case .duplicateBook(let existingTitle):
            "This audiobook is already in your library as \"\(existingTitle)\"."
        case .notAFolder:
            "Please select a folder containing audio files."
        }
    }
}

@MainActor
enum BookDeletionService {
    /// Removes the book from the library UI. Audio files in `Documents/Raven` are kept.
    static func delete(_ book: Book, modelContext: ModelContext, player: AudioPlayerService) {
        if player.currentBook?.id == book.id {
            player.stop()
        }
        modelContext.delete(book)
        try? modelContext.save()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
