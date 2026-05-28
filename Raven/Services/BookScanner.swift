import AVFoundation
import Foundation

struct ScannedChapter: Sendable {
    let title: String
    let relativePath: String
    let duration: TimeInterval
    let sortOrder: Int
}

struct ScanResult: Sendable {
    let title: String
    let author: String
    let chapters: [ScannedChapter]
    let artworkData: Data?
    let contentFingerprint: String
}

enum BookScanner {
    /// Scans a folder (with active security-scoped access) for supported audio files.
    static func scan(folderURL: URL) async throws -> ScanResult {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ScanError.enumerationFailed
        }

        var audioFiles: [(url: URL, name: String)] = []

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true, AudioFileTypes.isSupportedAudioFile(fileURL) else { continue }
            audioFiles.append((fileURL, values.name ?? fileURL.lastPathComponent))
        }

        guard !audioFiles.isEmpty else {
            throw ScanError.noAudioFiles
        }

        audioFiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var chapters: [ScannedChapter] = []
        var metadataTitle: String?
        var metadataAuthor: String?
        var artworkData: Data?

        for (index, file) in audioFiles.enumerated() {
            let relativePath = file.url.path
                .replacingOccurrences(of: folderURL.path + "/", with: "")
            let asset = AVURLAsset(url: file.url)
            let duration = try await asset.load(.duration).seconds
            let metadata = try await extractMetadata(from: asset)

            if index == 0 {
                metadataTitle = metadata.title
                metadataAuthor = metadata.author
                artworkData = metadata.artwork
            } else if artworkData == nil, let art = metadata.artwork {
                artworkData = art
            }

            let chapterTitle = metadata.title ?? file.name.deletingPathExtension
            chapters.append(ScannedChapter(
                title: chapterTitle,
                relativePath: relativePath,
                duration: duration.isFinite ? duration : 0,
                sortOrder: index
            ))
        }

        let bookTitle = metadataTitle ?? folderURL.lastPathComponent
        let fingerprint = BookFingerprint.make(from: chapters)
        return ScanResult(
            title: bookTitle,
            author: metadataAuthor ?? "",
            chapters: chapters,
            artworkData: artworkData,
            contentFingerprint: fingerprint
        )
    }

    private static func extractMetadata(from asset: AVURLAsset) async throws -> (title: String?, author: String?, artwork: Data?) {
        let metadata = try await asset.load(.commonMetadata)
        var title: String?
        var author: String?
        var artwork: Data?

        for item in metadata {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                title = item.stringValue
            case .commonKeyArtist, .commonKeyAuthor:
                if author == nil {
                    author = item.stringValue
                }
            case .commonKeyArtwork:
                if artwork == nil {
                    artwork = item.dataValue
                }
            default:
                break
            }
        }
        return (title, author, artwork)
    }
}

enum ScanError: LocalizedError {
    case enumerationFailed
    case noAudioFiles

    var errorDescription: String? {
        switch self {
        case .enumerationFailed:
            "Could not read the selected folder."
        case .noAudioFiles:
            "No supported audio files found in this folder."
        }
    }
}

private extension String {
    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }
}

private extension CMTime {
    var seconds: TimeInterval {
        CMTimeGetSeconds(self)
    }
}
