//
//  Chapter.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation
import SwiftData

@Model
final class Chapter {
    var id: UUID
    var title: String
    /// Filename relative to the book folder (e.g. "Chapter1.mp3").
    var relativePath: String
    /// Offset within `relativePath` for embedded chapters (e.g. M4B markers). Zero for whole-file chapters.
    var startTime: TimeInterval = 0
    var duration: TimeInterval
    var sortOrder: Int
    var transcriptionStateRaw: String

    var book: Book?

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.chapter)
    var segments: [TranscriptSegment]

    init(
        title: String,
        relativePath: String,
        duration: TimeInterval,
        sortOrder: Int,
        startTime: TimeInterval = 0
    ) {
        self.id = UUID()
        self.title = title
        self.relativePath = relativePath
        self.startTime = startTime
        self.duration = duration
        self.sortOrder = sortOrder
        self.transcriptionStateRaw = TranscriptionState.none.rawValue
        self.segments = []
    }

    var transcriptionState: TranscriptionState {
        get { TranscriptionState(rawValue: transcriptionStateRaw) ?? .none }
        set { transcriptionStateRaw = newValue.rawValue }
    }

    var sortedSegments: [TranscriptSegment] {
        segments.sorted { $0.sortOrder < $1.sortOrder }
    }

    var hasTranscript: Bool {
        transcriptionState == .completed && !segments.isEmpty
    }
}
