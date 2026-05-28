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
