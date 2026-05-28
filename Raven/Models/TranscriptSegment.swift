import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var sortOrder: Int

    var chapter: Chapter?

    init(startTime: TimeInterval, endTime: TimeInterval, text: String, sortOrder: Int) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.sortOrder = sortOrder
    }
}
