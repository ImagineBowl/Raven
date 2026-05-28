//
//  AudioSessionManager.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import AVFoundation

@MainActor
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private init() {}

    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
    }
}
