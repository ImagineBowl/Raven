//
//  BookFingerprint.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import CryptoKit
import Foundation

enum BookFingerprint {
    /// File layout identity — stable across rescans (paths only).
    nonisolated static func makePathIdentity(from chapters: [ScannedChapter]) -> String {
        let payload = chapters
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { chapterIdentity($0) }
            .joined(separator: "\n")
        return hash(payload)
    }

    static func makePathIdentity(from book: Book) -> String {
        let payload = book.sortedChapters
            .map { chapterIdentity(relativePath: $0.relativePath, startTime: $0.startTime) }
            .joined(separator: "\n")
        return hash(payload)
    }

    /// Full content identity including durations — used when importing new books.
    nonisolated static func make(from chapters: [ScannedChapter]) -> String {
        let payload = chapters
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { "\(chapterIdentity($0))|\(String(format: "%.3f", $0.duration))" }
            .joined(separator: "\n")
        return hash(payload)
    }

    static func make(from book: Book) -> String {
        let payload = book.sortedChapters
            .map {
                "\(chapterIdentity(relativePath: $0.relativePath, startTime: $0.startTime))|\(String(format: "%.3f", $0.duration))"
            }
            .joined(separator: "\n")
        return hash(payload)
    }

    nonisolated private static func chapterIdentity(_ chapter: ScannedChapter) -> String {
        chapterIdentity(relativePath: chapter.relativePath, startTime: chapter.startTime)
    }

    nonisolated private static func chapterIdentity(relativePath: String, startTime: TimeInterval) -> String {
        "\(relativePath)|\(String(format: "%.3f", startTime))"
    }

    nonisolated private static func hash(_ payload: String) -> String {
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
