//
//  AudioChapterSegmentExporter.swift
//  Raven
//
//  Created by Ahsan Minhas on 14/06/2026.
//

import AVFoundation
import Foundation

enum AudioChapterSegmentExporter {
    /// Exports a chapter time range to a temporary audio file for transcription.
    nonisolated static func exportSegment(
        from sourceURL: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw ExportError.sessionCreationFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("m4a")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        try await exportSession.export(to: outputURL, as: .m4a)
        return outputURL
    }
}

enum ExportError: LocalizedError {
    case sessionCreationFailed
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .sessionCreationFailed:
            "Could not prepare audio export for this chapter."
        case .cancelled:
            "Chapter audio export was cancelled."
        case .failed(let message):
            message
        }
    }
}
