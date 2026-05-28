//
//  SubtitleExporter.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation

enum SubtitleFormat: String, CaseIterable, Identifiable {
    case srt
    case vtt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .srt: "SRT"
        case .vtt: "VTT"
        }
    }

    var fileExtension: String { rawValue }
}

enum SubtitleExporter {
    static func export(segments: [TranscriptSegment], format: SubtitleFormat) -> String {
        let sorted = segments.sorted { $0.sortOrder < $1.sortOrder }
        switch format {
        case .srt:
            return exportSRT(sorted)
        case .vtt:
            return exportVTT(sorted)
        }
    }

    private static func exportSRT(_ segments: [TranscriptSegment]) -> String {
        segments.enumerated().map { index, segment in
            """
            \(index + 1)
            \(srtTimestamp(segment.startTime)) --> \(srtTimestamp(segment.endTime))
            \(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))

            """
        }.joined()
    }

    private static func exportVTT(_ segments: [TranscriptSegment]) -> String {
        let body = segments.map { segment in
            """
            \(vttTimestamp(segment.startTime)) --> \(vttTimestamp(segment.endTime))
            \(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))

            """
        }.joined()
        return "WEBVTT\n\n" + body
    }

    private static func srtTimestamp(_ seconds: TimeInterval) -> String {
        let totalMs = max(0, Int((seconds * 1000).rounded()))
        let ms = totalMs % 1000
        let totalSeconds = totalMs / 1000
        let s = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let m = totalMinutes % 60
        let h = totalMinutes / 60
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }

    private static func vttTimestamp(_ seconds: TimeInterval) -> String {
        srtTimestamp(seconds).replacingOccurrences(of: ",", with: ".")
    }
}
