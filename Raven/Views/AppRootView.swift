//
//  AppRootView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI
import SwiftData

/// Configures shared services and handles app lifecycle for playback and transcription.
struct AppRootView: View {
    /// Set to `true` when library/transcript search ships.
    private static let showsSearchTab = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AudioPlayerService.self) private var player
    @Environment(TranscriptionService.self) private var transcriptionService

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "book.closed.fill")
                }

            if Self.showsSearchTab {
                SearchPlaceholderView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(RavenDesign.Colors.primary)
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
