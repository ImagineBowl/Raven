//
//  ModelStorage.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation
import SwiftData

enum ModelStorage {
    static let shared: ModelContainer = {
        let schema = Schema([Book.self, Chapter.self, TranscriptSegment.self])
        let configuration = ModelConfiguration(
            "RavenStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Existing installs may fail lightweight migration after schema changes.
            // Remove the local store and recreate; library audio files on disk are kept.
            deletePersistentStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Could not create persistent ModelContainer: \(error)")
            }
        }
    }()

    private static func deletePersistentStore(at url: URL) {
        let fileManager = FileManager.default
        let candidates = [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal")
        ]
        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            try? fileManager.removeItem(at: candidate)
        }
    }
}
