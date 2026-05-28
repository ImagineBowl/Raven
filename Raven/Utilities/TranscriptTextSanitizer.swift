//
//  TranscriptTextSanitizer.swift
//  Raven
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import Foundation

enum TranscriptTextSanitizer {
    /// Whisper embeds special tokens like `<|2.60|>` for alignment — strip them from display text.
    nonisolated private static let specialTokenPattern = /<\|[^|>]*\|>/

    nonisolated static func clean(_ text: String) -> String {
        text.replacing(specialTokenPattern, with: " ")
            .replacing(/[ \t]+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
