import SwiftUI
import Combine

@MainActor
final class TeleprompterViewModel: ObservableObject {
    @Published var words: [TokenizedWord] = []
    @Published var currentWordIndex: Int = 0
    @Published var totalWords: Int = 0
    @Published var isPlaying: Bool = false
    @Published var isFinished: Bool = false
    @Published var permissionError: String?

    // Timer - starts when the first word is spoken, not when play is pressed
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
        guard totalWords > 0 else { return 0 }
        return Double(currentWordIndex) / Double(totalWords)
    }

    /// How far ahead or behind the speaker is, in seconds.
    /// Positive = ahead of schedule, negative = behind.
    var paceOffset: Double {
        guard hasTarget, totalWords > 0, elapsedSeconds > 0 else { return 0 }
        let expectedProgress = elapsedSeconds / Double(targetSeconds)
        let actualProgress = Double(currentWordIndex) / Double(totalWords)
        let diff = actualProgress - expectedProgress
        return diff * Double(targetSeconds)
    }

    /// Formatted elapsed time string
    var elapsedFormatted: String {
        formatTime(Int(elapsedSeconds))
    }

    /// Formatted remaining time (based on target or estimated)
    var remainingFormatted: String? {
        guard hasTarget else { return nil }
        let remaining = max(0, targetSeconds - Int(elapsedSeconds))
        return formatTime(remaining)
    }

    private var tokenizer = WordTokenizer()
    private var matchingEngine: TextMatchingEngine?
    private var audioCaptureManager = AudioCaptureManager()
    private var cancellables = Set<AnyCancellable>()

    /// Prepare the view model with a prompt (tokenize text, set up engine)
    func prepare(with prompt: Prompt) {
        words = tokenizer.tokenize(prompt.body)
        totalWords = words.count
        targetSeconds = prompt.targetSeconds

        let engine = TextMatchingEngine(words: words)
        self.matchingEngine = engine

        // Observe cursor changes from matching engine
        engine.$cursorIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let self else { return }
                self.currentWordIndex = index
                // Start timer on first word spoken
                if index > 0 && !self.timerStarted && self.isPlaying {
                    self.timerStarted = true
                    self.startTimer()
                }
                // Finish when last few words are reached -- wait 3 seconds to confirm
                if index >= self.totalWords - 3 && self.totalWords > 0 && !self.isFinished {
                    self.scheduleFinish()
                } else {
                    self.cancelScheduledFinish()
                }
            }
            .store(in: &cancellables)

        // Set up audio callback
        let vocabulary = tokenizer.uniqueVocabulary(from: words)
        audioCaptureManager.setContextualStrings(vocabulary)

        audioCaptureManager.onPartialResult = { [weak engine] recognizedWords in
            Task { @MainActor in
                engine?.processPartialResult(recognizedWords)
            }
        }
    }

    /// Start listening and matching
    func start(with prompt: Prompt) {
        if matchingEngine == nil {
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

    /// Called when the speaker reaches the end
    private func finish() {
        isFinished = true
        audioCaptureManager.stopListening()
        isPlaying = false
        if timerStarted { stopTimer() }
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
