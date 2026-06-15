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
    public private(set) var isSpeaking = false
    public var enabled = true

    public init() {}

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
