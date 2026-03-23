import SwiftUI
import Combine

enum PlaybackMode: Equatable {
    case script    // word-by-word matching
    case bullets   // bullet card matching
}

@MainActor
final class TeleprompterViewModel: ObservableObject {
    // Script mode
    @Published var words: [TokenizedWord] = []
    @Published var currentWordIndex: Int = 0
    @Published var totalWords: Int = 0

    // Bullet mode
    @Published var bullets: [BulletItem] = []
    @Published var currentBulletIndex: Int = 0
    @Published var completedBullets: Set<Int> = []

    // Shared state
    @Published var playbackMode: PlaybackMode = .script
    @Published var isPlaying: Bool = false
    @Published var isFinished: Bool = false
    @Published var permissionError: String?

    // Timer
    @Published var elapsedSeconds: Double = 0
    private var timerCancellable: AnyCancellable?
    private var startTime: Date?
    private var accumulatedTime: Double = 0
    private var timerStarted: Bool = false
    private var finishTask: Task<Void, Never>?

    // Target
    private(set) var targetSeconds: Int = 0
    var hasTarget: Bool { targetSeconds > 0 }

    var progress: Double {
        switch playbackMode {
        case .script:
            guard totalWords > 0 else { return 0 }
            return Double(currentWordIndex) / Double(totalWords)
        case .bullets:
            guard bullets.count > 0 else { return 0 }
            return Double(currentBulletIndex) / Double(bullets.count)
        }
    }

    var paceOffset: Double {
        guard hasTarget, elapsedSeconds > 0 else { return 0 }
        let expectedProgress = elapsedSeconds / Double(targetSeconds)
        let diff = progress - expectedProgress
        return diff * Double(targetSeconds)
    }

    var elapsedFormatted: String {
        formatTime(Int(elapsedSeconds))
    }

    // Engines
    private var tokenizer = WordTokenizer()
    private var matchingEngine: TextMatchingEngine?
    private var bulletEngine: BulletMatchingEngine?
    private var audioCaptureManager = AudioCaptureManager()
    private var cancellables = Set<AnyCancellable>()

    // Auto-fallback: track misses for switching script → bullets
    private var scriptConsecutiveMisses: Int = 0
    private let fallbackThreshold: Int = 16
    private var extractedBullets: [BulletItem] = []
    private var nativeBulletMode: Bool = false  // true if the prompt was written as bullets

    /// Prepare the view model with a prompt
    func prepare(with prompt: Prompt) {
        targetSeconds = prompt.targetSeconds

        if prompt.isBulletFormat {
            // Native bullet mode
            nativeBulletMode = true
            bullets = BulletDetector.parseBullets(prompt.body)
            playbackMode = .bullets
            setupBulletEngine()
        } else {
            // Script mode
            nativeBulletMode = false
            words = tokenizer.tokenize(prompt.body)
            totalWords = words.count
            playbackMode = .script
            setupScriptEngine()

            // Pre-load extracted bullets for fallback
            if prompt.hasExtractedBullets {
                extractedBullets = BulletDetector.parseBulletsFromExtracted(prompt.extractedBullets)
            } else {
                // Generate heuristic bullets as fallback
                Task {
                    let extracted = await KeyPointExtractor.extract(from: prompt.body)
                    self.extractedBullets = BulletDetector.parseBulletsFromExtracted(extracted)
                }
            }
        }
    }

    /// Start listening and matching
    func start(with prompt: Prompt) {
        if matchingEngine == nil && bulletEngine == nil {
            prepare(with: prompt)
        }

        Task {
            let permissions = await Permissions.checkAllPermissions()
            guard permissions.microphone else {
                permissionError = "Microphone access is required. Please enable it in Settings."
                return
            }
            guard permissions.speech else {
                permissionError = "Speech recognition access is required. Please enable it in Settings."
                return
            }

            audioCaptureManager.startListening()
            isPlaying = true
            if timerStarted { startTimer() }
        }
    }

    /// Pause listening
    func pause() {
        audioCaptureManager.stopListening()
        isPlaying = false
        if timerStarted { stopTimer() }
    }

    /// Stop and clean up
    func stop() {
        audioCaptureManager.stopListening()
        isPlaying = false
        stopTimer()
        cancellables.removeAll()
    }

    // MARK: - Script Engine Setup

    private func setupScriptEngine() {
        let engine = TextMatchingEngine(words: words)
        self.matchingEngine = engine

        engine.$cursorIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let self else { return }
                self.currentWordIndex = index
                self.scriptConsecutiveMisses = 0

                if index > 0 && !self.timerStarted && self.isPlaying {
                    self.timerStarted = true
                    self.startTimer()
                }

                if index >= self.totalWords - 3 && self.totalWords > 0 && !self.isFinished {
                    self.scheduleFinish()
                } else {
                    self.cancelScheduledFinish()
                }
            }
            .store(in: &cancellables)

        let vocabulary = tokenizer.uniqueVocabulary(from: words)
        audioCaptureManager.setContextualStrings(vocabulary)

        audioCaptureManager.onPartialResult = { [weak self, weak engine] recognizedWords in
            Task { @MainActor in
                guard let self else { return }

                if self.playbackMode == .script {
                    let prevIndex = engine?.cursorIndex ?? 0
                    engine?.processPartialResult(recognizedWords)
                    let newIndex = engine?.cursorIndex ?? 0

                    // Track misses for auto-fallback
                    if prevIndex == newIndex && !recognizedWords.isEmpty {
                        self.scriptConsecutiveMisses += 1
                        if self.scriptConsecutiveMisses >= self.fallbackThreshold && !self.extractedBullets.isEmpty {
                            self.switchToBullets()
                        }
                    }
                } else {
                    // In bullet mode, feed to bullet engine
                    self.bulletEngine?.processPartialResult(recognizedWords)

                    // Check if we should switch back to script
                    if !self.nativeBulletMode {
                        engine?.processPartialResult(recognizedWords)
                        let prevIndex = self.currentWordIndex
                        let newIndex = engine?.cursorIndex ?? 0
                        if newIndex > prevIndex + 3 {
                            // Script matching is working again
                            self.switchToScript()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bullet Engine Setup

    private func setupBulletEngine() {
        let engine = BulletMatchingEngine(bullets: bullets)
        self.bulletEngine = engine

        engine.$currentBulletIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let self else { return }
                self.currentBulletIndex = index

                if index > 0 && !self.timerStarted && self.isPlaying {
                    self.timerStarted = true
                    self.startTimer()
                }
            }
            .store(in: &cancellables)

        engine.$completedBullets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completed in
                guard let self else { return }
                self.completedBullets = completed

                // Check if all bullets completed
                if completed.count == self.bullets.count && !self.isFinished {
                    self.scheduleFinish()
                }
            }
            .store(in: &cancellables)

        // For native bullet mode, set up audio directly
        if nativeBulletMode {
            // Collect all keywords as contextual strings
            let allKeywords = bullets.flatMap { $0.keywords }
            audioCaptureManager.setContextualStrings(Array(Set(allKeywords)))

            audioCaptureManager.onPartialResult = { [weak engine] recognizedWords in
                Task { @MainActor in
                    engine?.processPartialResult(recognizedWords)
                }
            }
        }
    }

    // MARK: - Mode Switching

    private func switchToBullets() {
        bullets = extractedBullets
        setupBulletEngine()
        withAnimation(.easeInOut(duration: 0.4)) {
            playbackMode = .bullets
        }
        scriptConsecutiveMisses = 0
    }

    private func switchToScript() {
        withAnimation(.easeInOut(duration: 0.4)) {
            playbackMode = .script
        }
        scriptConsecutiveMisses = 0
    }

    // MARK: - Finish

    private func scheduleFinish() {
        guard finishTask == nil else { return }
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self.finish()
        }
    }

    private func cancelScheduledFinish() {
        finishTask?.cancel()
        finishTask = nil
    }

    private func finish() {
        isFinished = true
        bulletEngine?.finishAll()
        audioCaptureManager.stopListening()
        isPlaying = false
        if timerStarted { stopTimer() }
    }

    // MARK: - Timer

    private func startTimer() {
        startTime = Date()
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.startTime else { return }
                self.elapsedSeconds = self.accumulatedTime + Date().timeIntervalSince(start)
            }
    }

    private func stopTimer() {
        if let start = startTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        startTime = nil
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
