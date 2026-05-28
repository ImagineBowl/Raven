import SwiftUI
import SwiftData

/// Configures shared services and handles app lifecycle for playback and transcription.
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AudioPlayerService.self) private var player
    @Environment(TranscriptionService.self) private var transcriptionService

    var body: some View {
        LibraryView()
            .onAppear {
                player.configure(modelContext: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    player.handleAppBackgrounded()
                    transcriptionService.suspendForBackground(modelContext: modelContext)
                case .active:
                    player.checkSleepTimerExpiry()
                case .inactive:
                    player.handleAppBackgrounded()
                @unknown default:
                    break
                }
            }
    }
}
