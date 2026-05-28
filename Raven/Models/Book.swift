import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String
    /// Subfolder name inside `Documents/Raven` for library books.
    var folderName: String
    var sourceTypeRaw: String
    /// Legacy security-scoped bookmark for externally linked folders.
    var folderBookmark: Data
    var importedAt: Date
    var lastPlayedAt: Date?
    var totalDuration: TimeInterval
    var currentChapterIndex: Int
    var currentTime: TimeInterval
    var playbackRate: Float
    var artworkData: Data?
    var contentFingerprint: String

    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter]

    init(
        title: String,
        author: String = "",
        folderName: String = "",
        source: BookSource = .library,
        folderBookmark: Data = Data(),
        artworkData: Data? = nil,
        contentFingerprint: String = "",
        chapters: [Chapter] = []
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.folderName = folderName
        self.sourceTypeRaw = source.rawValue
        self.folderBookmark = folderBookmark
        self.importedAt = Date()
        self.totalDuration = 0
        self.currentChapterIndex = 0
        self.currentTime = 0
        self.playbackRate = 1.0
        self.artworkData = artworkData
        self.contentFingerprint = contentFingerprint
        self.chapters = chapters
    }

    var source: BookSource {
        get { BookSource(rawValue: sourceTypeRaw) ?? .external }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var sortedChapters: [Chapter] {
        chapters.sorted { $0.sortOrder < $1.sortOrder }
    }

    var progressFraction: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = sortedChapters.prefix(currentChapterIndex).reduce(0.0) { $0 + $1.duration }
        return min(1, (elapsed + currentTime) / totalDuration)
    }

    var isAvailable: Bool {
        switch source {
        case .library:
            FileManager.default.fileExists(atPath: RavenLibraryStore.folderURL(named: folderName).path)
        case .external:
            !folderBookmark.isEmpty
        }
    }

    func recalculateTotalDuration() {
        totalDuration = chapters.reduce(0) { $0 + $1.duration }
    }
}
