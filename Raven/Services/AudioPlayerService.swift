import AVFoundation
import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class AudioPlayerService {
    private(set) var currentBook: Book?
    private(set) var currentChapterIndex: Int = 0
    private(set) var currentTime: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var playbackRate: Float = 1.0
    private(set) var sleepTimerEndDate: Date?
    private(set) var isBedtimeModeEnabled = false

    var currentChapter: Chapter? {
        guard let book = currentBook else { return nil }
        let chapters = book.sortedChapters
        guard chapters.indices.contains(currentChapterIndex) else { return nil }
        return chapters[currentChapterIndex]
    }

    var bookElapsedTime: TimeInterval {
        guard let book = currentBook else { return 0 }
        let prior = book.sortedChapters.prefix(currentChapterIndex).reduce(0.0) { $0 + $1.duration }
        return prior + currentTime
    }

    var bookTotalDuration: TimeInterval {
        currentBook?.totalDuration ?? 0
    }

    private var player: AVPlayer?
    private var folderURL: URL?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var modelContext: ModelContext?
    private var progressSaveTask: Task<Void, Never>?
    private var sleepTimerTask: Task<Void, Never>?
    private var lastNowPlayingUpdate: TimeInterval = 0

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        try? AudioSessionManager.shared.configureForPlayback()
        setupRemoteCommands()
    }

    /// Saves playback position immediately — call when app backgrounds.
    func flushProgress() {
        progressSaveTask?.cancel()
        saveProgress()
    }

    func load(_ book: Book, autoPlay: Bool = false) async throws {
        stopInternal(clearNowPlaying: false)
        let url = try BookFolderAccess.openFolder(for: book)
        folderURL = url

        currentBook = book
        currentChapterIndex = min(book.currentChapterIndex, max(0, book.sortedChapters.count - 1))
        playbackRate = book.playbackRate

        try await playChapter(at: currentChapterIndex, seekTo: book.currentTime, autoPlay: autoPlay)
        book.lastPlayedAt = Date()
        saveProgress()
    }

    func togglePlayPause() {
        guard player != nil else { return }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard let player else { return }
        player.rate = playbackRate
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        saveProgress()
        updateNowPlaying()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, currentChapter?.duration ?? time))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        if let book = currentBook {
            book.currentTime = clamped
        }
        updateNowPlaying()
        flushProgress()
    }

    func seekBookPosition(_ position: TimeInterval) {
        guard let book = currentBook else { return }
        var remaining = max(0, position)
        for (index, chapter) in book.sortedChapters.enumerated() {
            if remaining <= chapter.duration {
                Task {
                    try? await playChapter(at: index, seekTo: remaining, autoPlay: isPlaying)
                }
                return
            }
            remaining -= chapter.duration
        }
        if let lastIndex = book.sortedChapters.indices.last {
            Task {
                try? await playChapter(at: lastIndex, seekTo: book.sortedChapters[lastIndex].duration, autoPlay: isPlaying)
            }
        }
    }

    func skipForward(seconds: TimeInterval = 30) {
        seek(to: currentTime + seconds)
    }

    func skipBackward(seconds: TimeInterval = 15) {
        seek(to: currentTime - seconds)
    }

    func playChapter(at index: Int) async throws {
        try await playChapter(at: index, seekTo: 0, autoPlay: isPlaying)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        currentBook?.playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlaying()
        saveProgress()
    }

    func toggleBedtimeMode() {
        setBedtimeMode(enabled: !isBedtimeModeEnabled)
    }

    func setBedtimeMode(enabled: Bool) {
        if enabled {
            isBedtimeModeEnabled = true
            setSleepTimer(minutes: BedtimeSettings.minutes)
        } else {
            isBedtimeModeEnabled = false
            setSleepTimer(minutes: nil)
        }
    }

    func setSleepTimer(minutes: Int?) {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerEndDate = nil

        guard let minutes, minutes > 0 else { return }

        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.pause()
                self?.sleepTimerEndDate = nil
                self?.isBedtimeModeEnabled = false
            }
        }
    }

    func stop() {
        stopInternal(clearNowPlaying: true)
    }

    // MARK: - Private

    private func playChapter(at index: Int, seekTo: TimeInterval, autoPlay: Bool) async throws {
        guard let book = currentBook, let folderURL else { return }
        let chapters = book.sortedChapters
        guard chapters.indices.contains(index) else { return }

        removePlayerObservers()
        player?.pause()
        player = nil

        let chapter = chapters[index]
        let fileURL = folderURL.appendingPathComponent(chapter.relativePath)
        let item = AVPlayerItem(url: fileURL)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        currentChapterIndex = index
        currentTime = seekTo

        let seekTime = CMTime(seconds: seekTo, preferredTimescale: 600)
        await newPlayer.seek(to: seekTime)

        addPlayerObservers(for: newPlayer, item: item)

        if autoPlay {
            newPlayer.rate = playbackRate
            isPlaying = true
        } else {
            isPlaying = false
        }

        book.currentChapterIndex = index
        book.currentTime = seekTo
        updateNowPlaying()
        saveProgress()
    }

    private func addPlayerObservers(for player: AVPlayer, item: AVPlayerItem) {
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                self.updateNowPlayingIfNeeded()
                self.scheduleProgressSave()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleChapterFinished()
            }
        }
    }

    private func handleChapterFinished() {
        guard let book = currentBook else { return }
        let nextIndex = currentChapterIndex + 1
        if book.sortedChapters.indices.contains(nextIndex) {
            Task {
                try? await playChapter(at: nextIndex, seekTo: 0, autoPlay: true)
            }
        } else {
            isPlaying = false
            currentTime = currentChapter?.duration ?? 0
            saveProgress()
            updateNowPlaying()
        }
    }

    private func scheduleProgressSave() {
        progressSaveTask?.cancel()
        progressSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveProgress()
        }
    }

    private func saveProgress() {
        guard let book = currentBook, let modelContext else { return }
        book.currentChapterIndex = currentChapterIndex
        book.currentTime = currentTime
        book.playbackRate = playbackRate
        book.lastPlayedAt = Date()
        do {
            try modelContext.save()
        } catch {
            // Keep in memory; next save attempt may succeed.
        }
    }

    private func stopInternal(clearNowPlaying: Bool) {
        removePlayerObservers()
        player?.pause()
        player = nil
        setBedtimeMode(enabled: false)
        saveProgress()
        releaseFolderAccess()
        currentBook = nil
        currentChapterIndex = 0
        currentTime = 0
        isPlaying = false
        if clearNowPlaying {
            NowPlayingManager.shared.clear()
        }
    }

    private func releaseFolderAccess() {
        if let folderURL, let book = currentBook {
            BookFolderAccess.releaseFolder(folderURL, for: book)
        }
        folderURL = nil
    }

    private func removePlayerObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func setupRemoteCommands() {
        NowPlayingManager.shared.configureRemoteCommands(
            play: { [weak self] in self?.play() },
            pause: { [weak self] in self?.pause() },
            togglePlayPause: { [weak self] in self?.togglePlayPause() },
            skipForward: { [weak self] in self?.skipForward() },
            skipBackward: { [weak self] in self?.skipBackward() },
            changePlaybackPosition: { [weak self] time in self?.seek(to: time) }
        )
    }

    private func updateNowPlayingIfNeeded() {
        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastNowPlayingUpdate >= 1.0 else { return }
        lastNowPlayingUpdate = now
        updateNowPlaying()
    }

    private func updateNowPlaying() {
        guard let book = currentBook, let chapter = currentChapter else { return }
        let artwork = book.artworkData.flatMap { UIImage(data: $0) }
        NowPlayingManager.shared.updateNowPlaying(
            title: chapter.title,
            artist: book.author.isEmpty ? book.title : book.author,
            duration: chapter.duration,
            elapsed: currentTime,
            rate: playbackRate,
            isPlaying: isPlaying,
            artwork: artwork
        )
    }
}

private extension CMTime {
    var seconds: TimeInterval {
        CMTimeGetSeconds(self)
    }
}
