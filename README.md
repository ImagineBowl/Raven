# Raven

A local-first audiobook player for iOS. Import folders of audio files, listen with background playback and lock screen controls, track progress per book and chapter, and generate on-device transcripts with Whisper.

## Features

- **Local library** — Drop audiobook folders in Files (`On My iPhone → Raven`) or use **Add Folder** in the app
- **Automatic import** — Scans your library folder on launch and when returning to the app
- **Playback** — Play/pause, skip ±15s/±30s, speed control (0.75×–2×), sleep timer
- **Progress** — Saves chapter index and timestamp; resumes where you left off
- **Background audio** — Lock screen and AirPods controls with artwork
- **Mini player** — Persistent bar when navigating away from the player
- **Transcripts** — On-device transcription via [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) with search and SRT/VTT export

## Requirements

- iOS 18+
- Xcode 16+
- Swift 5

## Getting started

1. Clone the repository
2. Open `Raven.xcodeproj` in Xcode
3. Select your device or simulator
4. Build and run (`Cmd + R`)

### Adding audiobooks

**Option A — Files app**

1. Open **Files → Browse → On My iPhone → Raven**
2. Create a folder for each book (e.g. `My Audiobook/`)
3. Add audio files inside (mp3, m4a, m4b, aac, wav, flac)
4. Open Raven — books appear automatically

**Option B — In app**

1. Tap **Add Folder** in the library
2. Pick a folder from Files — it is copied into your Raven library

## Architecture

```
Raven/
├── Models/           SwiftData (Book, Chapter, TranscriptSegment)
├── Services/         Audio, import, library sync, transcription
├── ViewModels/       Library and player state
├── Views/            SwiftUI screens and components
└── Utilities/        Shared helpers
```

- **MVVM** with `@Observable` view models
- **SwiftData** for persistence
- **AVFoundation** for playback
- **WhisperKit** for on-device speech-to-text

### Whisper model (developers)

The bundled Whisper `tiny` model (~73 MB) lives in `Raven/Resources/WhisperModels/`. After clone, if those files are missing, run:

```bash
./Scripts/fetch_whisper_model.sh
```

## Transcription

Raven ships with OpenAI Whisper (`tiny`) embedded in the app. Transcripts are generated on-device per chapter and stored locally for playback sync and export.

## License

MIT — see [LICENSE](LICENSE).
