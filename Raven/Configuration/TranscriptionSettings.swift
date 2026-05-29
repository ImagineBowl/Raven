//
//  TranscriptionSettings.swift
//  Raven
//
//  Created by Ahsan Minhas on 29/05/2026.
//

import Foundation

enum TranscriptionEngineKind: String, CaseIterable, Identifiable, Codable {
    case appleSpeech
    case whisper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSpeech: "Apple Speech"
        case .whisper: "Whisper"
        }
    }

    var summary: String {
        switch self {
        case .appleSpeech:
            "On-device · No large download"
        case .whisper:
            "On-device · One-time ~75 MB download"
        }
    }

    var detail: String {
        switch self {
        case .appleSpeech:
            "Uses Apple’s built-in speech recognition with a one-time permission. Good for quick starts and saving storage."
        case .whisper:
            "Runs OpenAI’s Whisper model locally. Download once, then transcribe offline — often strong on longer chapters."
        }
    }

    var isRecommended: Bool {
        self == .whisper
    }
}

enum TranscriptionSetupRequirement: Equatable {
    case speechAuthorization
    case whisperModelDownload(size: String)
}

enum TranscriptionReadiness: Equatable {
    case ready
    case needsSetup(TranscriptionSetupRequirement)
}

enum TranscriptionSettings {
    static let storageKey = "transcriptionEngineKind"
    static let defaultEngineKind: TranscriptionEngineKind = .appleSpeech

    static var engineKind: TranscriptionEngineKind {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey),
                  let kind = TranscriptionEngineKind(rawValue: raw) else {
                return defaultEngineKind
            }
            return kind
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
