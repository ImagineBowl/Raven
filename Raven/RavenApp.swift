import SwiftUI
import SwiftData

@main
struct RavenApp: App {
    @State private var player = AudioPlayerService()
    @State private var transcriptionService = TranscriptionService()

    init() {
        RavenLibraryStore.setupOnFirstLaunch()
        BackgroundTranscriptionCoordinator.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(player)
                .environment(transcriptionService)
        }
        .modelContainer(ModelStorage.shared)
    }
}
