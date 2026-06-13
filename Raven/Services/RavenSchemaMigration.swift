//
//  RavenSchemaMigration.swift
//  Raven
//
//  Created by Ahsan Minhas on 14/06/2026.
//

import Foundation
import SwiftData

// MARK: - Schema V1 (pre-M4B, no Chapter.startTime)

enum RavenSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Book.self, Chapter.self, TranscriptSegment.self]
    }

    @Model
    final class Book {
        var id: UUID
        var title: String
        var author: String
        var folderName: String
        var sourceTypeRaw: String
        var folderBookmark: Data
        var importedAt: Date
        var lastPlayedAt: Date?
        var totalDuration: TimeInterval
        var currentChapterIndex: Int
        var currentTime: TimeInterval
        var playbackRate: Float
        var artworkData: Data?
        var contentFingerprint: String

        @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
        var chapters: [Chapter]

        init(
            title: String,
            author: String = "",
            folderName: String = "",
            sourceTypeRaw: String = BookSource.library.rawValue,
            folderBookmark: Data = Data(),
            artworkData: Data? = nil,
            contentFingerprint: String = "",
            chapters: [Chapter] = []
        ) {
            self.id = UUID()
            self.title = title
            self.author = author
            self.folderName = folderName
            self.sourceTypeRaw = sourceTypeRaw
            self.folderBookmark = folderBookmark
            self.importedAt = Date()
            self.totalDuration = 0
            self.currentChapterIndex = 0
            self.currentTime = 0
            self.playbackRate = 1.0
            self.artworkData = artworkData
            self.contentFingerprint = contentFingerprint
            self.chapters = chapters
        }
    }

    @Model
    final class Chapter {
        var id: UUID
        var title: String
        var relativePath: String
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
            transcriptionStateRaw: String = TranscriptionState.none.rawValue
        ) {
            self.id = UUID()
            self.title = title
            self.relativePath = relativePath
            self.duration = duration
            self.sortOrder = sortOrder
            self.transcriptionStateRaw = transcriptionStateRaw
            self.segments = []
        }
    }

    @Model
    final class TranscriptSegment {
        var id: UUID
        var startTime: TimeInterval
        var endTime: TimeInterval
        var text: String
        var sortOrder: Int

        var chapter: Chapter?

        init(
            startTime: TimeInterval,
            endTime: TimeInterval,
            text: String,
            sortOrder: Int
        ) {
            self.id = UUID()
            self.startTime = startTime
            self.endTime = endTime
            self.text = text
            self.sortOrder = sortOrder
        }
    }
}

// MARK: - Schema V2 (M4B embedded chapters)

enum RavenSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Book.self, Chapter.self, TranscriptSegment.self]
    }
}

// MARK: - Migration plan

enum RavenSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RavenSchemaV1.self, RavenSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Adds `Chapter.startTime` for embedded M4B chapter markers.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: RavenSchemaV1.self,
        toVersion: RavenSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let chapters = try context.fetch(FetchDescriptor<Chapter>())
            for chapter in chapters {
                chapter.startTime = 0
            }
            try context.save()
        }
    )
}
