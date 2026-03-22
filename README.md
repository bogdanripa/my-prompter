# My Prompter

A voice-powered teleprompter for iOS. Speak and the words follow.

My Prompter listens to your voice and scrolls your text automatically — no foot pedals, no remote controls, no scrolling by hand. Just speak and it keeps up.

## How It Works

Instead of traditional speech-to-text, My Prompter uses **forced alignment**: since it knows exactly what you should be saying, it fuzzy-matches your voice against the known text to determine where you are. This makes it robust to accents, background noise, and filler words.

1. Paste or type your text
2. Hit play and start speaking
3. The app highlights each word as you say it

Pause and it waits. Speed up and it follows. Skip a paragraph and it finds you.

## Features

- **Voice-activated auto-scroll** with karaoke-style word highlighting
- **On-device speech recognition** — no internet required, fully private
- **Pace feedback** — set a target time and the highlight color tells you if you're ahead or behind
- **Works in tough conditions** — noisy rooms, accents, imperfect pronunciation
- **Multiple prompts** — manage all your scripts in one place
- **iCloud sync** — access your prompts across devices
- **Mirror mode** — for glass teleprompter setups
- **Universal** — works on iPhone and iPad

## Use Cases

- Conference talks and keynotes
- Pitch rehearsals and investor meetings
- Wedding speeches and toasts
- Video scripts and content creation
- Karaoke and sing-alongs

## Tech Stack

- **SwiftUI** + **SwiftData** (iOS 17+)
- **Apple Speech framework** (`SFSpeechRecognizer`) — on-device, partial results
- **AVFoundation** (`AVAudioEngine`) — audio capture
- **CloudKit** — iCloud sync
- Zero third-party dependencies

## Architecture

```
Prompter/
  PrompterApp.swift              — Entry point, seed data
  Models/
    Prompt.swift                 — SwiftData model
  Views/
    PromptListView.swift         — Main list (NavigationSplitView)
    PromptRowView.swift          — List row
    PromptEditorView.swift       — Text editor with target time
    TeleprompterView.swift       — Full-screen play mode
    FlowLayout.swift             — Word-wrapping layout
    SettingsView.swift           — App settings
  ViewModels/
    TeleprompterViewModel.swift  — Orchestrates audio + matching + UI
  Engine/
    AudioCaptureManager.swift    — AVAudioEngine + SFSpeechRecognizer
    TextMatchingEngine.swift     — Forced alignment with proximity bias
    WordTokenizer.swift          — Text tokenization with ranges
    FuzzyMatcher.swift           — Levenshtein distance + sliding window
  Utilities/
    Permissions.swift            — Mic + speech authorization
    Constants.swift              — App-wide defaults
  Extensions/
    String+Normalized.swift      — String cleaning
```

## Core Algorithm

The matching engine maintains a cursor position and searches a window of expected words around it. As `SFSpeechRecognizer` emits partial results, the last few recognized words are fuzzy-matched (Levenshtein distance) against the expected window. A proximity bias favors positions near the cursor, so sequential reading is responsive while paragraph skips are still detected.

## Building

1. Open `Prompter.xcodeproj` in Xcode 15+
2. Set your Development Team in Signing & Capabilities
3. Enable iCloud with CloudKit capability
4. Build and run on a physical device (microphone required)

## License

All rights reserved.
