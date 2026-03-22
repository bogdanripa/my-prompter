import Foundation
import AVFoundation
import Speech

@MainActor
final class AudioCaptureManager: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var errorMessage: String?

    /// Callback with recognized words from partial results
    var onPartialResult: (([String]) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var contextualStrings: [String] = []

    // Auto-restart timer to avoid 60-second limit
    private var restartTimer: Timer?
    private let restartInterval: TimeInterval = 50

    /// Set vocabulary hints from the prompt text
    func setContextualStrings(_ strings: [String]) {
        self.contextualStrings = strings
    }

    /// Start listening and processing speech
    func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            return
        }

        errorMessage = nil

        do {
            try startAudioEngineAndRecognition()
            isListening = true
            scheduleRestart()
        } catch {
            errorMessage = "Failed to start audio capture: \(error.localizedDescription)"
        }
    }

    /// Stop listening
    func stopListening() {
        restartTimer?.invalidate()
        restartTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        isListening = false
    }

    // MARK: - Private

    private func startAudioEngineAndRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Configure audio session -- playAndRecord allows music to play simultaneously (karaoke)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation

        if !contextualStrings.isEmpty {
            request.contextualStrings = contextualStrings
        }

        self.recognitionRequest = request

        // Install tap on audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Remove existing tap if any
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        guard let speechRecognizer else { return }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let words = result.bestTranscription.formattedString
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }

                Task { @MainActor in
                    self.onPartialResult?(words)
                }
            }

            if let error {
                // Ignore cancellation errors (expected during restart)
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    // Recognition was cancelled, this is expected
                    return
                }

                Task { @MainActor in
                    // Only set error if we're supposed to be listening
                    if self.isListening {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// Restart recognition every ~50 seconds to avoid the 60-second limit
    private func scheduleRestart() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: restartInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isListening else { return }
                try? self.startAudioEngineAndRecognition()
            }
        }
    }
}
