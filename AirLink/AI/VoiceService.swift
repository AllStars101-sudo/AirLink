import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
class VoiceService: NSObject {
    // MARK: - Speech Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()
    
    // MARK: - State
    private var isRecording = false
    private var currentTranscription = ""
    
    override init() {
        super.init()
        synthesizer.delegate = self
        requestPermissions()
    }
    
    // MARK: - Permissions
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized")
                @unknown default:
                    print("Unknown speech recognition authorization status")
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Microphone access granted")
                } else {
                    print("Microphone access denied")
                }
            }
        }
    }
    
    // MARK: - Speech Recognition Methods
    func startListening() async throws -> String {
        guard !isRecording else {
            throw VoiceError.alreadyRecording
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceError.speechRecognitionUnavailable
        }
        
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        currentTranscription = ""
        
        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    self.currentTranscription = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.stopListening()
                        continuation.resume(returning: self.currentTranscription)
                    }
                } else if let error = error {
                    self.stopListening()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Text-to-Speech Methods
    func speak(_ text: String) async {
        guard !synthesizer.isSpeaking else { return }
        
        // Configure audio session for playback
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [])
        try? audioSession.setActive(true)
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure voice - using a more natural sounding voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        utterance.rate = 0.5 // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        await withCheckedContinuation { continuation in
            // Store continuation to resume when speech finishes
            speechContinuation = continuation
            synthesizer.speak(utterance)
        }
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Helper Properties
    var isListeningForSpeech: Bool {
        return isRecording
    }
    
    var isSpeaking: Bool {
        return synthesizer.isSpeaking
    }
    
    // MARK: - Private Properties
    private var speechContinuation: CheckedContinuation<Void, Never>?
}

// MARK: - AVSpeechSynthesizerDelegate
extension VoiceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        speechContinuation?.resume()
        speechContinuation = nil
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speechContinuation?.resume()
        speechContinuation = nil
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Error Types
enum VoiceError: LocalizedError {
    case alreadyRecording
    case speechRecognitionUnavailable
    case recognitionRequestFailed
    case microphoneAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Already recording audio"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available"
        case .recognitionRequestFailed:
            return "Failed to create speech recognition request"
        case .microphoneAccessDenied:
            return "Microphone access is required for voice input"
        }
    }
}