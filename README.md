# My Prompter

A voice-powered teleprompter for iOS. Speak and the words follow.

My Prompter listens to your voice and scrolls your text automatically — no foot pedals, no remote controls, no scrolling by hand. Just speak and it keeps up.

## How It Works

My Prompter supports two modes, auto-detected from your content:

### Script Mode
Paste or type a full script. My Prompter uses **forced alignment** — since it knows exactly what you should be saying, it fuzzy-matches your voice against the known text to determine where you are. This makes it robust to accents, background noise, and filler words.

1. Paste or type your text
2. Hit play and start speaking
3. The app highlights each word as you say it

Pause and it waits. Speed up and it follows. Skip a paragraph and it finds you.

### Bullet Point Mode
Write your talking points as a bulleted list (`-`, `*`, `•`, `→`, `#`, or numbered). My Prompter shows them as cards and checks them off as you cover each point using keyword matching. Speak freely in your own words — no need to memorize a script.

If you go off-script while in script mode, the app automatically switches to bullet point view (if key points have been extracted) and switches back when you resume reading.

## Features

- **Voice-activated auto-scroll** with karaoke-style word highlighting
- **Bullet point mode** with card-based UI and checkmarks
- **Auto-detection** — writes bullets? Gets cards. Writes a script? Gets word tracking.
- **Extract key points** from scripts (on-device LLM on iOS 26+, heuristic fallback)
- **Auto-fallback** — switches to bullet view when you go off-script
- **On-device speech recognition** — no internet required, fully private
- **Pace feedback** — set a target time; the highlighted word and timer change color
- **Works in tough conditions** — noisy rooms, accents, imperfect pronunciation
- **Multiple prompts** — manage all your scripts and notes in one place
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
- **Foundation Models** (iOS 26+) — on-device LLM for key point extraction
- Zero third-party dependencies

## Architecture

```
Prompter/
  PrompterApp.swift              — Entry point, seed data, iCloud config
  Models/
    Prompt.swift                 — SwiftData model (script + extracted bullets)
  Views/
    PromptListView.swift         — Main list (NavigationSplitView)
    PromptRowView.swift          — List row
    PromptEditorView.swift       — Text editor with target time + key points
    TeleprompterView.swift       — Full-screen play mode (script + bullet views)
    FlowLayout.swift             — Word-wrapping layout with line break support
    SettingsView.swift           — App settings
  ViewModels/
    TeleprompterViewModel.swift  — Orchestrates audio + matching + UI + mode switching
  Engine/
    AudioCaptureManager.swift    — AVAudioEngine + SFSpeechRecognizer
    TextMatchingEngine.swift     — Forced alignment with proximity bias
    BulletDetector.swift         — Auto-detect bullet format, parse, extract keywords
    BulletMatchingEngine.swift   — Keyword matching for bullet points
    KeyPointExtractor.swift      — LLM + heuristic key point extraction
    WordTokenizer.swift          — Text tokenization with character ranges
    FuzzyMatcher.swift           — Levenshtein distance + sliding window
  Utilities/
    Permissions.swift            — Mic + speech authorization
  Extensions/
    String+Normalized.swift      — String cleaning
    Int+TimeFormat.swift         — Time formatting (M:SS)
```

## Core Algorithm

### Script Matching
The matching engine maintains a cursor position and searches a large forward window (80 words) of expected text. As `SFSpeechRecognizer` emits partial results, the last few recognized words are fuzzy-matched (Levenshtein distance) against the window. A proximity bias favors positions near the cursor, so sequential reading is responsive while paragraph skips are still detected. Consecutive confirmation prevents false jumps.

### Bullet Matching
Each bullet point's significant keywords (stop words removed, longest words prioritized) are compared against recent speech using fuzzy matching. When enough keywords are detected, the bullet is marked complete and the next one is highlighted.

## Building

1. Open `Prompter.xcodeproj` in Xcode 15+
2. Set your Development Team in Signing & Capabilities
3. Enable iCloud with CloudKit capability
4. Build and run on a physical device (microphone required)

## Privacy

All speech recognition is processed on-device. No audio data is sent to any server. Prompts sync via iCloud only if enabled on your device.

## License

All rights reserved.
