import Foundation

enum RavenLibraryStore {
    /// Audiobook folders live directly in the app Documents directory.
    /// Visible in Files as: On My iPhone → Raven
    static var rootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static let welcomeFileName = "Drop audiobook folders here.txt"

    static func ensureExists() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    /// Creates Documents folder content on first launch so the app appears in Files.
    static func setupOnFirstLaunch() {
        try? ensureExists()
        writeWelcomeFileIfNeeded()
    }

    private static func writeWelcomeFileIfNeeded() {
        let welcomeURL = rootURL.appendingPathComponent(welcomeFileName)
        guard !FileManager.default.fileExists(atPath: welcomeURL.path) else { return }

        let text = """
        Welcome to Raven

        Create a folder here for each audiobook, then add your audio files inside it.

        Example:
          My Audiobook/
            Chapter 1.mp3
            Chapter 2.mp3

        Open Files → Browse → On My iPhone → Raven

        You can also tap "Add Folder" inside the Raven app to copy a folder here.
        """
        try? text.write(to: welcomeURL, atomically: true, encoding: .utf8)
    }

    static func folderURL(named name: String) -> URL {
        rootURL.appendingPathComponent(name, isDirectory: true)
    }

    /// Subfolders in Documents that contain at least one audio file.
    static func audiobookFolders() throws -> [URL] {
        try ensureExists()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        let contents = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        return contents.filter { url in
            guard !isReservedItem(url) else { return false }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return false
            }
            return containsSupportedAudio(in: url)
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func containsSupportedAudio(in folderURL: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return false }

        for case let fileURL as URL in enumerator {
            if AudioFileTypes.isSupportedAudioFile(fileURL) {
                return true
            }
        }
        return false
    }

    static func uniqueDestinationURL(for sourceName: String) -> URL {
        try? ensureExists()
        var candidate = folderURL(named: sourceName)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let base = (sourceName as NSString).deletingPathExtension
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL(named: "\(base) \(counter)")
            counter += 1
        }
        return candidate
    }

    static var filesAppPathDescription: String {
        "Files → Browse → On My iPhone → Raven"
    }

    private static func isReservedItem(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix(".") || name == "Inbox" || name == welcomeFileName
    }
}
