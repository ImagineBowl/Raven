//
//  EmbeddedChapterScanner.swift
//  Raven
//
//  Created by Ahsan Minhas on 14/06/2026.
//

import AVFoundation
import Foundation

struct EmbeddedChapterInfo: Equatable, Sendable {
    let title: String
    let startTime: TimeInterval
    let duration: TimeInterval
}

enum EmbeddedChapterScanner {
    /// Returns embedded chapters when the asset exposes more than one chapter marker; otherwise `nil`.
    nonisolated static func scanEmbeddedChapters(
        in asset: AVURLAsset,
        relativePath: String,
        fallbackTitle: String,
        sortOrderStart: Int
    ) async throws -> [ScannedChapter]? {
        let assetDuration = try await asset.load(.duration).seconds
        let timedGroups = try await loadTimedChapterGroups(from: asset)

        var parsedGroups: [(start: TimeInterval, end: TimeInterval, title: String?)] = []
        parsedGroups.reserveCapacity(timedGroups.count)

        for group in timedGroups {
            let start = group.timeRange.start.seconds
            let end = CMTimeAdd(group.timeRange.start, group.timeRange.duration).seconds
            let title = await title(from: group)
            parsedGroups.append((start: start, end: end, title: title))
        }

        let chapterInfos = chapterInfos(
            from: parsedGroups,
            assetDuration: assetDuration,
            fallbackTitle: fallbackTitle
        )
        guard !chapterInfos.isEmpty else { return nil }

        return chapterInfos.enumerated().map { offset, info in
            ScannedChapter(
                title: info.title,
                relativePath: relativePath,
                duration: info.duration,
                sortOrder: sortOrderStart + offset,
                startTime: info.startTime
            )
        }
    }

    /// Builds chapter metadata from timed groups. Requires at least two markers to treat the file as segmented.
    nonisolated static func chapterInfos(
        from groups: [(start: TimeInterval, end: TimeInterval, title: String?)],
        assetDuration: TimeInterval,
        fallbackTitle: String
    ) -> [EmbeddedChapterInfo] {
        guard groups.count > 1 else { return [] }

        let sortedGroups = groups.sorted { $0.start < $1.start }
        var chapters: [EmbeddedChapterInfo] = []
        chapters.reserveCapacity(sortedGroups.count)

        for (index, group) in sortedGroups.enumerated() {
            let start = max(0, group.start)
            let end = resolvedEndTime(
                for: group,
                at: index,
                in: sortedGroups,
                assetDuration: assetDuration
            )
            let duration = max(0, end - start)
            guard duration > 0 else { continue }

            let title = group.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = (title?.isEmpty == false ? title! : "\(fallbackTitle) \(index + 1)")

            chapters.append(
                EmbeddedChapterInfo(
                    title: resolvedTitle,
                    startTime: start,
                    duration: duration
                )
            )
        }

        return chapters
    }

    nonisolated private static func resolvedEndTime(
        for group: (start: TimeInterval, end: TimeInterval, title: String?),
        at index: Int,
        in sortedGroups: [(start: TimeInterval, end: TimeInterval, title: String?)],
        assetDuration: TimeInterval
    ) -> TimeInterval {
        if group.end.isFinite, group.end > group.start {
            return group.end
        }
        if index + 1 < sortedGroups.count {
            return sortedGroups[index + 1].start
        }
        return assetDuration.isFinite ? assetDuration : group.start
    }

    nonisolated private static func loadTimedChapterGroups(from asset: AVURLAsset) async throws -> [AVTimedMetadataGroup] {
        let preferredGroups = try await asset.loadChapterMetadataGroups(
            bestMatchingPreferredLanguages: Locale.preferredLanguages
        )
        if !preferredGroups.isEmpty {
            return preferredGroups
        }

        let chapterLocales = try await asset.load(.availableChapterLocales)
        for locale in chapterLocales {
            let localeGroups = try await asset.loadChapterMetadataGroups(
                withTitleLocale: locale,
                containingItemsWithCommonKeys: []
            )
            if !localeGroups.isEmpty {
                return localeGroups
            }
        }

        return []
    }

    nonisolated private static func title(from group: AVTimedMetadataGroup) async -> String? {
        for item in group.items {
            if let key = item.commonKey, key == .commonKeyTitle,
               let value = try? await item.load(.stringValue),
               !value.isEmpty {
                return value
            }
            if let value = try? await item.load(.stringValue), !value.isEmpty {
                return value
            }
        }
        return nil
    }
}

private extension CMTime {
    nonisolated var seconds: TimeInterval {
        let value = CMTimeGetSeconds(self)
        return value.isFinite ? value : 0
    }
}
