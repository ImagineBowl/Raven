//
//  SecurityScopedBookmarkStore.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation

enum BookmarkAccess {
    private static var bookmarkOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        .withSecurityScope
        #else
        .minimalBookmark
        #endif
    }

    private static var resolveOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        .withSecurityScope
        #else
        []
        #endif
    }

    /// Resolves a security-scoped bookmark and begins access. Caller must call `stopAccessingSecurityScopedResource()` on the returned URL when done.
    static func resolveFolderURL(from bookmarkData: Data) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: resolveOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            throw BookmarkError.staleBookmark
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        return url
    }

    static func createBookmark(for folderURL: URL) throws -> Data {
        try folderURL.bookmarkData(
            options: bookmarkOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}

enum BookmarkError: LocalizedError {
    case staleBookmark
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .staleBookmark:
            "The book folder is no longer accessible. Re-import the folder from Files."
        case .accessDenied:
            "Could not access the book folder. Check Files permissions."
        }
    }
}
