//
//  CoverImageTypes.swift
//  Raven
//
//  Created by Ahsan Minhas on 08/06/2026.
//

import Foundation
import ImageIO

enum CoverImageTypes {
    nonisolated static let preferredBaseNames: [String] = [
        "cover", "folder", "artwork", "art", "front"
    ]

    nonisolated static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp"
    ]

    /// Looks for a cover image in the book folder root when audio files have no embedded artwork.
    nonisolated static func findCoverImage(in folderURL: URL) -> Data? {
        guard let rootFiles = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let imageFiles = rootFiles.filter { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return false
            }
            return isSupportedImage(url)
        }

        for preferredName in preferredBaseNames {
            if let match = imageFiles.first(where: {
                $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(preferredName) == .orderedSame
            }), let data = loadValidatedImageData(from: match) {
                return data
            }
        }

        let remaining = imageFiles
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        for url in remaining {
            if let data = loadValidatedImageData(from: url) {
                return data
            }
        }

        return nil
    }

    nonisolated static func isSupportedImage(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    nonisolated static func loadValidatedImageData(from url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              isValidImageData(data) else {
            return nil
        }
        return data
    }

    nonisolated private static func isValidImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }
}
