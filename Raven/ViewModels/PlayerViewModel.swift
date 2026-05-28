import Foundation

@MainActor
@Observable
final class PlayerViewModel {
    let playbackRates: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    let sleepTimerOptions: [Int?] = [nil, 15, 30, 45, 60]

    var showChapterList = false
    var showSleepTimer = false
    var isScrubbing = false
    var scrubValue: TimeInterval = 0

    func bind(to player: AudioPlayerService) {
        if !isScrubbing {
            scrubValue = player.bookElapsedTime
        }
    }

    func beginScrubbing(player: AudioPlayerService) {
        isScrubbing = true
        scrubValue = player.bookElapsedTime
    }

    func endScrubbing(player: AudioPlayerService) {
        isScrubbing = false
        player.seekBookPosition(scrubValue)
    }

    func sleepTimerLabel(for minutes: Int?) -> String {
        guard let minutes else { return "Off" }
        return "\(minutes) min"
    }
}
