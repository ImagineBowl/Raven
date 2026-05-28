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
    var duration: TimeInterval
    var sortOrder: Int
    var transcriptionStateRaw: String

    var book: Book?

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.chapter)
    var segments: [TranscriptSegment]

    init(title: String, relativePath: String, duration: TimeInterval, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.relativePath = relativePath
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
