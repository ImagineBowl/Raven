//
//  RavenApp.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI
import SwiftData

@main
struct RavenApp: App {
    @AppStorage(AppearanceSettings.storageKey) private var appearanceRaw = AppAppearance.system.rawValue
    @State private var player = AudioPlayerService()
    @State private var transcriptionService = TranscriptionService()
    @State private var showLaunchScreen = true

    private var preferredColorScheme: ColorScheme? {
        (AppAppearance(rawValue: appearanceRaw) ?? AppearanceSettings.defaultAppearance).preferredColorScheme
    }

    init() {
        RavenLibraryStore.setupOnFirstLaunch()
        BackgroundTranscriptionCoordinator.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showLaunchScreen {
                    LaunchScreenView(isPresented: $showLaunchScreen)
                } else {
                    AppRootView()
                        .environment(player)
                        .environment(transcriptionService)
                }
            }
            .preferredColorScheme(preferredColorScheme)
        }
        .modelContainer(ModelStorage.shared)
    }
}
