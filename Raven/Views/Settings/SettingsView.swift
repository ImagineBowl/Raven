//
//  SettingsView.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AudioPlayerService.self) private var player
    @AppStorage(BedtimeSettings.storageKey) private var bedtimeMinutes = BedtimeSettings.defaultMinutes

    var body: some View {
        Form {
            Section {
                Stepper(value: $bedtimeMinutes, in: 5...180, step: 5) {
                    Text("Pause after \(bedtimeMinutes) minutes")
                }
            } header: {
                Text("Bedtime Mode")
            } footer: {
                Text("When bedtime mode is on, playback automatically pauses after this duration.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: bedtimeMinutes) { _, newValue in
            BedtimeSettings.minutes = newValue
            if player.isBedtimeModeEnabled {
                player.setBedtimeMode(enabled: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AudioPlayerService())
    }
}
