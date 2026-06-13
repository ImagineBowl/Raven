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
        let schema = Schema(versionedSchema: RavenSchemaV2.self)
        let configuration = ModelConfiguration(
            "RavenStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: RavenSchemaMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            fatalError("Could not create persistent ModelContainer: \(error)")
        }
    }()
}
