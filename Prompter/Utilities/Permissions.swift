import AVFoundation
import Speech

enum Permissions {
    static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestSpeechRecognitionAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static func checkAllPermissions() async -> (microphone: Bool, speech: Bool) {
        let mic = await requestMicrophoneAccess()
        let speech = await requestSpeechRecognitionAccess()
        return (mic, speech)
    }
}
