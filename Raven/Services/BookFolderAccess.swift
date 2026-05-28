import Foundation

enum BookFolderError: LocalizedError {
    case missing
    case invalidBookmark

    var errorDescription: String? {
        switch self {
        case .missing:
            "This audiobook folder is no longer in your Raven library."
        case .invalidBookmark:
            "Could not access this audiobook. Add it to the Raven folder in Files."
        }
    }
}

enum BookFolderAccess {
    /// Opens the audiobook folder. For external books, starts security-scoped access.
    static func openFolder(for book: Book) throws -> URL {
        switch book.source {
        case .library:
            let url = RavenLibraryStore.folderURL(named: book.folderName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw BookFolderError.missing
            }
            return url
        case .external:
            guard !book.folderBookmark.isEmpty else {
                throw BookFolderError.invalidBookmark
            }
            return try BookmarkAccess.resolveFolderURL(from: book.folderBookmark)
        }
    }

    static func releaseFolder(_ url: URL, for book: Book) {
        if book.source == .external {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
