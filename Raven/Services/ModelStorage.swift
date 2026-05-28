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
            fatalError("Could not create persistent ModelContainer: \(error)")
        }
    }()
}
