import SwiftUI
import SwiftData

/// Configures shared services and flushes playback progress when the app backgrounds.
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AudioPlayerService.self) private var player

    var body: some View {
        LibraryView()
            .onAppear {
                player.configure(modelContext: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    player.flushProgress()
                }
            }
    }
}
