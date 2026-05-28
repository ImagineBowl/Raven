import UniformTypeIdentifiers

enum AudioFileTypes {
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "flac", "aiff", "caf"
    ]

    static let contentTypes: [UTType] = [
        .mp3, .mpeg4Audio, .audio, .wav, .aiff
    ]

    static func isSupportedAudioFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
