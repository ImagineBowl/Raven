//
//  WhisperKitTranscriptionEngine.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import CoreML
import Foundation
import WhisperKit

enum WhisperModelError: LocalizedError {
    case bundledModelMissing
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledModelMissing:
            "The bundled Whisper model is missing from the app. Reinstall Raven or contact support."
        case .loadFailed(let detail):
            "Could not load the Whisper model.\n\(detail)"
        }
    }
}

actor WhisperKitTranscriptionEngine {
    static let shared = WhisperKitTranscriptionEngine()

    private static let modelVariant = "openai_whisper-tiny"

    private var whisperKit: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> [TimedSegment] {
        let kit = try await loadWhisperKit(onProgress: onProgress)
        onProgress?("Transcribing audio…")

        var decodeOptions = DecodingOptions()
        decodeOptions.skipSpecialTokens = true
        decodeOptions.topK = 1

        let results = try await kit.transcribe(
            audioPath: audioURL.path(percentEncoded: false),
            decodeOptions: decodeOptions
        )

        guard let result = results.first else { return [] }

        return result.segments.compactMap { segment in
            let text = TranscriptTextSanitizer.clean(segment.text)
            guard !text.isEmpty else { return nil }
            return TimedSegment(
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end),
                text: text
            )
        }
    }

    func isModelAvailable() -> Bool {
        Self.resolvedModelFolder() != nil
    }

    func resetModelCache() async {
        whisperKit = nil
        loadTask?.cancel()
        loadTask = nil
    }

    func cancelActiveWork() {
        loadTask?.cancel()
        loadTask = nil
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
        onProgress?("Loading Whisper model…")

        guard let modelFolder = Self.resolvedModelFolder() else {
            throw WhisperModelError.bundledModelMissing
        }

        return try await initializeWhisperKit(modelFolder: modelFolder, onProgress: onProgress)
    }

    private func initializeWhisperKit(
        modelFolder: URL,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> WhisperKit {
        onProgress?("Preparing Whisper model…")
        let computeOptions = ModelComputeOptions(
            melCompute: .cpuAndNeuralEngine,
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine,
            prefillCompute: .cpuOnly
        )
        let config = WhisperKitConfig(
            modelFolder: modelFolder.path(percentEncoded: false),
            computeOptions: computeOptions,
            prewarm: true,
            load: true,
            download: false
        )
        do {
            return try await WhisperKit(config)
        } catch {
            throw WhisperModelError.loadFailed(error.localizedDescription)
        }
    }

    private static func resolvedModelFolder() -> URL? {
        bundledModelFolder ?? legacyDownloadedModelFolder
    }

    private static var bundledModelFolder: URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }

        let nestedFolder = resourceURL
            .appendingPathComponent("WhisperModels", isDirectory: true)
            .appendingPathComponent(modelVariant, isDirectory: true)
        if validateModel(at: nestedFolder) {
            return nestedFolder
        }

        // Xcode may flatten bundled Core ML folders to the app resource root.
        if validateModel(at: resourceURL) {
            return resourceURL
        }

        return nil
    }

    /// Supports transcripts generated before the model was bundled in the app.
    private static var legacyDownloadedModelFolder: URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents
            .appendingPathComponent("huggingface/models", isDirectory: true)
            .appendingPathComponent("argmaxinc/whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(modelVariant, isDirectory: true)
        guard validateModel(at: folder) else { return nil }
        return folder
    }

    private static func validateModel(at folder: URL) -> Bool {
        let requiredComponents = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
        return requiredComponents.allSatisfy { name in
            let url = ModelUtilities.detectModelURL(inFolder: folder, named: name)
            return FileManager.default.fileExists(atPath: url.path)
        }
    }
}
