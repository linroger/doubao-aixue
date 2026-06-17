//
//  SpeechService.swift
//  豆包爱学
//
//  Text-to-speech (teacher narration, dictation read-aloud, translation) via
//  AVSpeechSynthesizer, plus a lightweight speech-recognition coordinator.
//  TTS works on-device/offline on both iOS and macOS.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
public final class TTSService {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = TTSDelegate()
    public private(set) var isSpeaking = false
    public var enabled = true

    public init() {
        synthesizer.delegate = delegate
        // When narration actually finishes (or is cancelled), reset the flag so
        // 'speaking' indicators (tutor chalk waveform, read-aloud toggles) stop.
        delegate.onFinish = { [weak self] in
            Task { @MainActor in self?.isSpeaking = false }
        }
    }

    /// Speak text in the given BCP-47 language (default Simplified Chinese).
    public func speak(_ text: String, language: String = "zh-CN", rate: Float = 0.5) {
        guard enabled, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05      // warm "大姐姐" tone
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

/// Non-isolated AVSpeechSynthesizer delegate shim. Kept separate from TTSService so
/// the @MainActor @Observable service doesn't have to expose nonisolated callbacks;
/// the closure hops back to the main actor.
private final class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (@Sendable () -> Void)?
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { onFinish?() }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { onFinish?() }
}

// MARK: - Speech recognition coordinator (hold-to-talk)

/// Coordinates the "是否听懂了 / 追问" hold-to-talk loop. Live on-device ASR
/// (SFSpeechRecognizer / SpeechAnalyzer) is a documented integration seam; this
/// build returns deterministic transcripts so the loop is fully demoable.
@MainActor
@Observable
public final class SpeechRecognitionCoordinator {
    public private(set) var isListening = false
    public private(set) var transcript = ""

    public init() {}

    public func startListening() {
        isListening = true
        transcript = ""
    }

    /// Stop and return the recognized utterance.
    public func stopListening(simulated: String = "听懂了") -> String {
        isListening = false
        transcript = simulated
        return simulated
    }

    public static var isAvailable: Bool { false }   // real ASR seam
}
