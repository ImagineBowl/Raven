import Foundation

enum TranscriptionState: String, Codable {
    case none
    case processing
    case completed
    case failed
}
