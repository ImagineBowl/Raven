import Foundation

enum TranscriptTextSanitizer {
    /// Whisper embeds special tokens like `<|2.60|>` for alignment — strip them from display text.
    private static let specialTokenPattern = /<\|[^|>]*\|>/

    static func clean(_ text: String) -> String {
        text.replacing(specialTokenPattern, with: " ")
            .replacing(/[ \t]+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
