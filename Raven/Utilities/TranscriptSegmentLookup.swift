//
//  TranscriptSegmentLookup.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation

enum TranscriptSegmentLookup {
    /// Binary search for the segment active at `time` in sorted segments.
    static func segment(at time: TimeInterval, in segments: [TranscriptSegment]) -> TranscriptSegment? {
        guard !segments.isEmpty else { return nil }

        var lower = 0
        var upper = segments.count - 1

        while lower <= upper {
            let mid = (lower + upper) / 2
            let segment = segments[mid]

            if time < segment.startTime {
                upper = mid - 1
            } else if time >= segment.endTime {
                lower = mid + 1
            } else {
                return segment
            }
        }

        return nil
    }
}
