import Foundation
import SwiftData

@MainActor
@Observable
final class LibraryViewModel {
    var isImporting = false
    var isSyncing = false
    var showDocumentPicker = false
    var errorMessage: String?

    func syncLibrary(modelContext: ModelContext) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let service = BookImportService(modelContext: modelContext)
            _ = try await service.syncLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFolderToLibrary(url: URL, modelContext: ModelContext, player: AudioPlayerService) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let service = BookImportService(modelContext: modelContext)
            let book = try await service.addFolderToLibrary(from: url)
            try await player.load(book, autoPlay: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
