import Foundation
import WhisperKit

enum WhisperModelError: LocalizedError {
    case downloadFailed(String)
    case modelFilesMissing(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let detail):
            "Could not download the Whisper model. Check your internet connection and try again.\n\(detail)"
        case .modelFilesMissing(let path):
            "Whisper model files are incomplete. Tap Try Again to re-download.\nMissing: \(path)"
        case .loadFailed(let detail):
            "Could not load the Whisper model.\n\(detail)"
        }
    }
}

actor WhisperKitTranscriptionEngine {
    static let shared = WhisperKitTranscriptionEngine()

    private static let modelVariant = "openai_whisper-base"
    private static let modelRepo = "argmaxinc/whisperkit-coreml"

    private var whisperKit: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> [TimedSegment] {
        let kit = try await loadWhisperKit(onProgress: onProgress)
        onProgress?("Transcribing audio…")
        let results = try await kit.transcribe(audioPath: audioURL.path(percentEncoded: false))

        guard let result = results.first else { return [] }

        return result.segments.compactMap { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TimedSegment(
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end),
                text: text
            )
        }
    }

    func resetModelCache() async {
        whisperKit = nil
        loadTask?.cancel()
        loadTask = nil
        removeDownloadedModel()
    }

    // MARK: - Private

    private func loadWhisperKit(onProgress: (@Sendable (String) -> Void)? = nil) async throws -> WhisperKit {
        if let whisperKit { return whisperKit }
        if let loadTask { return try await loadTask.value }

        let task = Task<WhisperKit, Error> {
            try await prepareWhisperKit(onProgress: onProgress)
        }
        loadTask = task

        do {
            let kit = try await task.value
            whisperKit = kit
            loadTask = nil
            return kit
        } catch {
            loadTask = nil
            throw error
        }
    }

    private func prepareWhisperKit(onProgress: (@Sendable (String) -> Void)? = nil) async throws -> WhisperKit {
        onProgress?("Checking Whisper model…")

        var modelFolder = cachedModelFolderIfValid()
        if modelFolder == nil {
            onProgress?("Downloading Whisper model (~140 MB)…")
            modelFolder = try await downloadModel(onProgress: onProgress)
        }

        guard let modelFolder, Self.validateModel(at: modelFolder) else {
            removeDownloadedModel()
            onProgress?("Re-downloading Whisper model…")
            let redownloaded = try await downloadModel(onProgress: onProgress)
            guard Self.validateModel(at: redownloaded) else {
                throw WhisperModelError.modelFilesMissing(Self.melSpectrogramPath(in: redownloaded))
            }
            return try await initializeWhisperKit(modelFolder: redownloaded, onProgress: onProgress)
        }

        do {
            return try await initializeWhisperKit(modelFolder: modelFolder, onProgress: onProgress)
        } catch {
            removeDownloadedModel()
            onProgress?("Model load failed. Downloading fresh copy…")
            let freshFolder = try await downloadModel(onProgress: onProgress)
            guard Self.validateModel(at: freshFolder) else {
                throw WhisperModelError.modelFilesMissing(Self.melSpectrogramPath(in: freshFolder))
            }
            return try await initializeWhisperKit(modelFolder: freshFolder, onProgress: onProgress)
        }
    }

    private func initializeWhisperKit(
        modelFolder: URL,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> WhisperKit {
        onProgress?("Loading Whisper model…")
        let config = WhisperKitConfig(
            modelFolder: modelFolder.path(percentEncoded: false),
            prewarm: true,
            load: true,
            download: false,
            useBackgroundDownloadSession: true
        )
        do {
            return try await WhisperKit(config)
        } catch {
            throw WhisperModelError.loadFailed(error.localizedDescription)
        }
    }

    private func downloadModel(onProgress: (@Sendable (String) -> Void)? = nil) async throws -> URL {
        do {
            return try await WhisperKit.download(
                variant: Self.modelVariant,
                useBackgroundSession: true,
                from: Self.modelRepo,
                progressCallback: { progress in
                    let percent = Int(progress.fractionCompleted * 100)
                    onProgress?("Downloading Whisper model… \(percent)%")
                }
            )
        } catch {
            throw WhisperModelError.downloadFailed(error.localizedDescription)
        }
    }

    private func cachedModelFolderIfValid() -> URL? {
        let folder = Self.defaultModelFolder
        guard Self.validateModel(at: folder) else { return nil }
        return folder
    }

    private func removeDownloadedModel() {
        whisperKit = nil
        let folder = Self.defaultModelFolder
        let repoFolder = folder.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
        // Remove repo folder if empty after deleting variant.
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: repoFolder.path),
           contents.isEmpty {
            try? FileManager.default.removeItem(at: repoFolder)
        }
    }

    private static var defaultModelFolder: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents
            .appendingPathComponent("huggingface/models")
            .appendingPathComponent(modelRepo)
            .appendingPathComponent(modelVariant)
    }

    private static func validateModel(at folder: URL) -> Bool {
        let requiredComponents = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
        return requiredComponents.allSatisfy { name in
            let url = ModelUtilities.detectModelURL(inFolder: folder, named: name)
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    private static func melSpectrogramPath(in folder: URL) -> String {
        ModelUtilities.detectModelURL(inFolder: folder, named: "MelSpectrogram").path
    }
}
