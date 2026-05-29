//
//  TranscriptSegmentGrouper.swift
//  Raven
//
//  Created by Ahsan Minhas on 29/05/2026.
//

import Foundation

enum TranscriptSegmentGrouper {
    /// Normalizes segments for lyrics display — merges word-level Apple Speech output, preserves Whisper lines.
    static func normalize(_ segments: [TimedSegment]) -> [TimedSegment] {
        guard !segments.isEmpty else { return [] }
        if isWordLevelTimed(segments) {
            return group(segments)
        }
        return extendLineEndTimes(segments.sorted { $0.startTime < $1.startTime })
    }

    static func normalizeStored(_ segments: [TranscriptSegment]) -> [TimedSegment] {
        let timed = segments
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { TimedSegment(startTime: $0.startTime, endTime: $0.endTime, text: $0.text) }
        return normalize(timed)
    }

    /// Merges word-level speech segments into lyric-style lines.
    static func group(
        _ segments: [TimedSegment],
        maxWords: Int = 12,
        maxDuration: TimeInterval = 8
    ) -> [TimedSegment] {
        guard !segments.isEmpty else { return [] }

        let sorted = segments.sorted { $0.startTime < $1.startTime }
        var grouped: [TimedSegment] = []
        var batch: [TimedSegment] = []

        func flush() {
            guard !batch.isEmpty else { return }
            grouped.append(
                TimedSegment(
                    startTime: batch[0].startTime,
                    endTime: batch[batch.count - 1].endTime,
                    text: batch.map(\.text).joined(separator: " ")
                )
            )
            batch = []
        }

        for segment in sorted {
            batch.append(segment)

            let span = batch[batch.count - 1].endTime - batch[0].startTime
            let endsSentence = segment.text.last.map { ".!?".contains($0) } ?? false

            if batch.count >= maxWords || span >= maxDuration || (endsSentence && batch.count >= 3) {
                flush()
            }
        }

        flush()
        return extendLineEndTimes(grouped)
    }

    static func isWordLevel(_ segments: [TranscriptSegment]) -> Bool {
        isWordLevelTimed(
            segments.map { TimedSegment(startTime: $0.startTime, endTime: $0.endTime, text: $0.text) }
        )
    }

    private static func isWordLevelTimed(_ segments: [TimedSegment]) -> Bool {
        guard segments.count >= 6 else { return false }
        let shortLines = segments.filter {
            $0.text.split(whereSeparator: \.isWhitespace).count <= 2
        }.count
        return Double(shortLines) / Double(segments.count) > 0.6
    }

    private static func extendLineEndTimes(_ lines: [TimedSegment]) -> [TimedSegment] {
        guard !lines.isEmpty else { return [] }

        return lines.enumerated().map { index, line in
            let endTime: TimeInterval
            if index + 1 < lines.count {
                endTime = lines[index + 1].startTime
            } else {
                endTime = line.endTime
            }
            return TimedSegment(startTime: line.startTime, endTime: endTime, text: line.text)
        }
    }
}
