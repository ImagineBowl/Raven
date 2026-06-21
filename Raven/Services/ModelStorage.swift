//
//  ModelStorage.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation
import os
import SwiftData

enum ModelStorage {
    static let configurationName = "RavenStore"
    static let resyncAfterRecoveryKey = "RavenNeedsLibraryResyncAfterStoreRecovery"

    static let shared: ModelContainer = {
        createPersistentContainer()
    }()

    static var needsLibraryResyncAfterRecovery: Bool {
        get { UserDefaults.standard.bool(forKey: resyncAfterRecoveryKey) }
        set { UserDefaults.standard.set(newValue, forKey: resyncAfterRecoveryKey) }
    }

    private static func createPersistentContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: RavenSchemaV2.self)
        let configuration = makeConfiguration()

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: RavenSchemaMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            RavenLog.modelStorage.error("ModelContainer creation failed: \(error.localizedDescription, privacy: .public)")
            deleteStoreFiles(for: configuration)

            do {
                needsLibraryResyncAfterRecovery = true
                return try ModelContainer(
                    for: schema,
                    migrationPlan: RavenSchemaMigrationPlan.self,
                    configurations: configuration
                )
            } catch {
                fatalError("Could not create persistent ModelContainer after reset: \(error)")
            }
        }
    }

    private static func makeConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            configurationName,
            schema: Schema(versionedSchema: RavenSchemaV2.self),
            isStoredInMemoryOnly: false
        )
    }

    private static func deleteStoreFiles(for configuration: ModelConfiguration) {
        let fileManager = FileManager.default
        let relatedURLs = [
            configuration.url,
            URL(fileURLWithPath: configuration.url.path + "-shm"),
            URL(fileURLWithPath: configuration.url.path + "-wal")
        ]

        for url in relatedURLs where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                RavenLog.modelStorage.error("Failed to delete store file at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
