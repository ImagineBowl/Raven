//
//  TranscriptSegmentLookup.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation

enum TranscriptSegmentLookup {
    /// Returns the lyric line active at `time` in sorted segments.
    static func segment(at time: TimeInterval, in segments: [TranscriptSegment]) -> TranscriptSegment? {
        guard !segments.isEmpty else { return nil }

        if time <= segments[0].startTime {
            return segments[0]
        }

        if time >= segments[segments.count - 1].endTime {
            return segments[segments.count - 1]
        }

        var lower = 0
        var upper = segments.count - 1

        while lower <= upper {
            let mid = (lower + upper) / 2
            let segment = segments[mid]

            if time < segment.startTime {
                upper = mid - 1
            } else if mid + 1 < segments.count, time >= segments[mid + 1].startTime {
                lower = mid + 1
            } else {
                return segment
            }
        }

        return segments[lower]
    }
}
