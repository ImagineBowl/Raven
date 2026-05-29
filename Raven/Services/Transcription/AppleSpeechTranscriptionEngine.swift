//
//  AppleSpeechTranscriptionEngine.swift
//  Raven
//
//  Created by Ahsan Minhas on 29/05/2026.
//

import AVFoundation
import Foundation
import Speech

enum AppleSpeechError: LocalizedError {
    case authorizationDenied
    case onDeviceNotAvailable
    case recognizerUnavailable
    case recognitionFailed(String)
    case audioExportFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Speech recognition access was denied. Enable it in Settings to generate transcripts."
        case .onDeviceNotAvailable:
            "On-device speech recognition isn’t available for your language on this device."
        case .recognizerUnavailable:
            "Speech recognition is unavailable right now."
        case .recognitionFailed(let detail):
            "Speech recognition failed.\n\(detail)"
        case .audioExportFailed:
            "Could not prepare audio for speech recognition."
        case .cancelled:
            "Transcription was stopped."
        }
    }
}

actor AppleSpeechTranscriptionEngine {
    static let shared = AppleSpeechTranscriptionEngine()

    private static let chunkDuration: TimeInterval = 5 * 60

    private var recognitionTask: SFSpeechRecognitionTask?

    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func isReady() -> Bool {
        authorizationStatus() == .authorized && isOnDeviceAvailable
    }

    func requestAuthorization(onProgress: (@Sendable (String) -> Void)? = nil) async throws {
        onProgress?("Requesting speech recognition access…")

        let status: SFSpeechRecognizerAuthorizationStatus
        if authorizationStatus() == .notDetermined {
            status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        } else {
            status = authorizationStatus()
        }

        guard status == .authorized else {
            throw AppleSpeechError.authorizationDenied
        }
        guard isOnDeviceAvailable else {
            throw AppleSpeechError.onDeviceNotAvailable
        }
    }

    func transcribe(
        audioURL: URL,
        audioDuration: TimeInterval? = nil,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> [TimedSegment] {
        if !isReady() {
            try await requestAuthorization(onProgress: onProgress)
        }

        let resolvedDuration: TimeInterval
        if let audioDuration, audioDuration > 0 {
            resolvedDuration = audioDuration
        } else {
            resolvedDuration = await Self.loadDuration(for: audioURL)
        }

        if resolvedDuration > Self.chunkDuration {
            return try await transcribeInChunks(
                audioURL: audioURL,
                totalDuration: resolvedDuration,
                onProgress: onProgress
            )
        }

        onProgress?("Transcribing audio…")
        return try await transcribeFile(
            audioURL: audioURL,
            timeOffset: 0,
            progressDuration: max(resolvedDuration, 1),
            onProgress: onProgress
        )
    }

    func cancelActiveWork() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    func resetStorage() async {}

    // MARK: - Private

    private func transcribeInChunks(
        audioURL: URL,
        totalDuration: TimeInterval,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> [TimedSegment] {
        let asset = AVURLAsset(url: audioURL)
        let chunkCount = max(1, Int(ceil(totalDuration / Self.chunkDuration)))
        var merged: [TimedSegment] = []

        for index in 0..<chunkCount {
            try Task.checkCancellation()

            let start = TimeInterval(index) * Self.chunkDuration
            let chunkLength = min(Self.chunkDuration, totalDuration - start)
            onProgress?("Transcribing part \(index + 1) of \(chunkCount)…")

            let chunkURL = try await Self.exportChunk(
                asset: asset,
                start: start,
                duration: chunkLength
            )
            defer { try? FileManager.default.removeItem(at: chunkURL) }

            let chunkSegments = try await transcribeFile(
                audioURL: chunkURL,
                timeOffset: start,
                progressDuration: chunkLength,
                onProgress: { message in
                    onProgress?(message)
                }
            )
            merged.append(contentsOf: chunkSegments)
        }

        return merged
    }

    private func transcribeFile(
        audioURL: URL,
        timeOffset: TimeInterval,
        progressDuration: TimeInterval,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> [TimedSegment] {
        try await withCheckedThrowingContinuation { continuation in
            guard !Task.isCancelled else {
                continuation.resume(throwing: AppleSpeechError.cancelled)
                return
            }

            guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                continuation.resume(throwing: AppleSpeechError.recognizerUnavailable)
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true

            var hasFinished = false
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                guard !hasFinished else { return }

                if let error {
                    hasFinished = true
                    continuation.resume(throwing: AppleSpeechError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let result else { return }

                if let lastTimestamp = result.bestTranscription.segments.last?.timestamp {
                    let processed = min(lastTimestamp, progressDuration)
                    let percent = Int((processed / progressDuration) * 100)
                    onProgress?("Transcribing audio… \(percent)%")
                }

                guard result.isFinal else { return }
                hasFinished = true

                let wordSegments = result.bestTranscription.segments.compactMap { segment -> TimedSegment? in
                    let text = TranscriptTextSanitizer.clean(segment.substring)
                    guard !text.isEmpty else { return nil }
                    return TimedSegment(
                        startTime: timeOffset + segment.timestamp,
                        endTime: timeOffset + segment.timestamp + segment.duration,
                        text: text
                    )
                }

                let lines = TranscriptSegmentGrouper.normalize(wordSegments)
                continuation.resume(returning: lines)
            }
        }
    }

    private var isOnDeviceAvailable: Bool {
        guard let recognizer = SFSpeechRecognizer() else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    private static func loadDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration), duration.isNumeric else {
            return 0
        }
        return max(duration.seconds, 0)
    }

    private static func exportChunk(
        asset: AVURLAsset,
        start: TimeInterval,
        duration: TimeInterval
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AppleSpeechError.audioExportFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: AppleSpeechError.cancelled)
                default:
                    continuation.resume(throwing: AppleSpeechError.audioExportFailed)
                }
            }
        }

        return outputURL
    }
}
