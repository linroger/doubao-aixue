//
//  TutorSessionModel.swift
//  豆包爱学 — Features/Tutor
//
//  View model for 豆包老师 — the voice-first, dynamic-blackboard tutor (RESEARCH
//  §4.2 F18–F22). It consumes `intelligence.tutorSession(_:)` as an
//  AsyncThrowingStream, drives the animated 动态板书 forward one TutorSegment at a
//  time in sync with TTS narration, pauses at a TutorCheckpoint for the
//  "是否听懂了?" comprehension loop, supports replaying a step ("再讲一遍"), pacing,
//  and free-form 追问 (interrupt + ask a follow-up via the chat stream).
//
//  All state lives here so the views stay declarative. The model is MainActor
//  isolated (the default) and never touches the network — the injected mock
//  services return rich, deterministic, fully-offline content.
//

import SwiftUI
import Observation

// MARK: - Session phases

/// The discrete states the tutor moves through (RESEARCH F18/F19 state lists).
enum TutorPhase: Equatable {
    case idle            // before the stream starts
    case teaching        // speaking + drawing a segment
    case checkpoint      // paused, asking "是否听懂了?"
    case awaitingVoice   // hold-to-talk capturing the student's reply
    case replaying       // re-teaching the previous step
    case answering       // a 追问 follow-up is being answered
    case finished        // session complete
    case failed(String)  // stream error (offline / generation failed)
}

/// A single 追问 follow-up exchange anchored to the session.
struct TutorFollowUp: Identifiable, Hashable {
    let id = UUID()
    var role: ChatRole
    var text: String
    var atSegmentIndex: Int
}

@MainActor
@Observable
final class TutorSessionModel {

    // MARK: Inputs
    let request: TutorRequest

    // MARK: Streamed content
    /// Every segment received so far. The blackboard renders the *current* one,
    /// while the transcript (字幕) shows all narrations.
    private(set) var segments: [TutorSegment] = []
    /// Index into `segments` of the segment currently on the board.
    private(set) var currentIndex: Int = 0
    private(set) var phase: TutorPhase = .idle
    private(set) var route: IntelligenceRoute = .mock
    private(set) var hasFinishedStreaming = false

    // MARK: Board reveal animation
    /// How many BoardElements of the current segment have been revealed. The
    /// blackboard animates them in one by one for the "draws as it talks" feel.
    private(set) var revealedElementCount: Int = 0

    // MARK: Checkpoint
    private(set) var activeCheckpoint: TutorCheckpoint?

    // MARK: Follow-ups (追问)
    private(set) var followUps: [TutorFollowUp] = []
    private(set) var isAnsweringFollowUp = false

    // MARK: Voice / transcript
    var transcriptExpanded = false
    var ttsEnabled = true
    /// Speaking pace, mapped to AVSpeechUtterance rate. 0.75x … 1.5x (RESEARCH F22).
    var paceMultiplier: Double = 1.0 {
        didSet { paceMultiplier = min(1.5, max(0.75, paceMultiplier)) }
    }

    // MARK: Convenience accessors
    var currentSegment: TutorSegment? {
        segments.indices.contains(currentIndex) ? segments[currentIndex] : nil
    }
    /// The board elements that should currently be visible (progressive reveal).
    var visibleBoardElements: [BoardElement] {
        guard let board = currentSegment?.board else { return [] }
        return Array(board.prefix(revealedElementCount))
    }
    /// Whether the student can advance to the next received segment.
    var canAdvance: Bool {
        guard case .teaching = phase else { return false }
        return currentIndex < segments.count - 1
    }
    var hasPreviousSegment: Bool { currentIndex > 0 }
    /// Overall progress through the received segments (0…1).
    var progress: Double {
        guard !segments.isEmpty else { return 0 }
        let denominator = max(segments.count - 1, 1)
        return min(1, Double(currentIndex) / Double(denominator))
    }
    var isFinished: Bool { if case .finished = phase { return true }; return false }
    var statusLabel: String {
        switch phase {
        case .idle: "准备中…"
        case .teaching: "豆包老师讲解中"
        case .checkpoint: "等你回答"
        case .awaitingVoice: "正在听你说…"
        case .replaying: "再讲一遍"
        case .answering: "豆包老师思考中…"
        case .finished: "讲解完成"
        case .failed: "暂时无法讲解"
        }
    }

    // MARK: Private
    private var streamTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var followUpTask: Task<Void, Never>?
    private let intelligence: any IntelligenceService
    private let tts: TTSService

    init(request: TutorRequest, intelligence: any IntelligenceService, tts: TTSService) {
        self.request = request
        self.intelligence = intelligence
        self.tts = tts
    }

    // MARK: - Lifecycle

    /// Begin (or restart) the streamed session. Safe to call once on appear.
    func start() {
        guard case .idle = phase else { return }
        beginStreaming()
    }

    func retry() {
        cancelEverything()
        segments = []
        currentIndex = 0
        revealedElementCount = 0
        activeCheckpoint = nil
        hasFinishedStreaming = false
        phase = .idle
        beginStreaming()
    }

    func tearDown() {
        cancelEverything()
        tts.stop()
    }

    private func cancelEverything() {
        streamTask?.cancel(); streamTask = nil
        revealTask?.cancel(); revealTask = nil
        followUpTask?.cancel(); followUpTask = nil
    }

    private func beginStreaming() {
        phase = .teaching
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in self.intelligence.tutorSession(self.request) {
                    if Task.isCancelled { return }
                    switch event {
                    case .segment(let segment):
                        self.ingest(segment)
                    case .done:
                        self.hasFinishedStreaming = true
                    }
                }
                // Stream completed normally.
                self.hasFinishedStreaming = true
                self.markFinishedIfDone()
            } catch is CancellationError {
                return
            } catch {
                self.phase = .failed("讲解加载失败了，检查网络后再试试吧～")
            }
        }
    }

    /// Append a freshly streamed segment. The first one becomes the active board
    /// and starts narrating; later ones simply queue up so the student can pace.
    private func ingest(_ segment: TutorSegment) {
        let wasEmpty = segments.isEmpty
        segments.append(segment)
        if wasEmpty {
            currentIndex = 0
            presentCurrentSegment()
        }
    }

    // MARK: - Presentation of a segment

    /// Reveal the current segment: narrate it (TTS), animate its board elements
    /// in, and surface a checkpoint if one is attached.
    private func presentCurrentSegment() {
        guard let segment = currentSegment else { return }
        activeCheckpoint = nil
        revealedElementCount = 0
        phase = .teaching

        narrate(segment.narration)
        revealBoardElements(count: segment.board.count) { [weak self] in
            guard let self else { return }
            if let checkpoint = segment.checkpoint {
                self.enterCheckpoint(checkpoint)
            } else {
                self.markFinishedIfDone()
            }
        }
    }

    /// Animate the blackboard elements appearing one at a time.
    private func revealBoardElements(count: Int, completion: @escaping () -> Void) {
        revealTask?.cancel()
        guard count > 0 else { completion(); return }
        revealTask = Task { [weak self] in
            guard let self else { return }
            for step in 1...count {
                if Task.isCancelled { return }
                withAnimation(.spring(duration: 0.45)) {
                    self.revealedElementCount = step
                }
                HapticEngine.play(.light)
                try? await Task.sleep(nanoseconds: 360_000_000)
            }
            if Task.isCancelled { return }
            completion()
        }
    }

    private func enterCheckpoint(_ checkpoint: TutorCheckpoint) {
        activeCheckpoint = checkpoint
        phase = .checkpoint
        HapticEngine.play(.selection)
        narrate(checkpoint.prompt)
    }

    /// Once the stream is done AND the last segment is on screen, mark finished.
    private func markFinishedIfDone() {
        guard hasFinishedStreaming else { return }
        if currentIndex >= segments.count - 1, activeCheckpoint == nil {
            phase = .finished
            HapticEngine.play(.success)
        }
    }

    // MARK: - Pacing / navigation

    /// Advance to the next received segment ("继续").
    func advance() {
        guard currentIndex < segments.count - 1 else {
            markFinishedIfDone(); return
        }
        currentIndex += 1
        presentCurrentSegment()
    }

    /// Re-teach the segment currently on the board ("再讲一遍" / replay).
    func replayCurrent() {
        phase = .replaying
        activeCheckpoint = nil
        HapticEngine.play(.light)
        presentCurrentSegment()
    }

    /// Step back to the previous segment (manual review).
    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        presentCurrentSegment()
    }

    /// Jump to a given received segment and present it ("再听一遍" / transcript jump).
    func replayFrom(_ index: Int) {
        guard segments.indices.contains(index) else { return }
        currentIndex = index
        presentCurrentSegment()
    }

    /// Re-read the current narration aloud without re-animating the board.
    func repeatNarration() {
        guard let segment = currentSegment else { return }
        narrate(segment.narration)
    }

    // MARK: - Checkpoint resolution (是否听懂了?)

    /// Resolve the checkpoint from a structured choice (typed-reply fallback).
    /// `understood == true` → continue; otherwise replay the step.
    func resolveCheckpoint(understood: Bool) {
        guard activeCheckpoint != nil else { return }
        activeCheckpoint = nil
        if understood {
            HapticEngine.play(.success)
            if currentIndex < segments.count - 1 {
                advance()
            } else {
                markFinishedIfDone()
            }
        } else {
            replayCurrent()
        }
    }

    /// Resolve the checkpoint from a free-form voice/typed transcript. Maps the
    /// utterance to understood / confused intent (RESEARCH F19 intent mapping).
    func resolveCheckpoint(fromTranscript transcript: String) {
        let understood = Self.transcriptMeansUnderstood(transcript)
        resolveCheckpoint(understood: understood)
    }

    /// The student begins holding the mic during a checkpoint.
    func beginVoiceReply() {
        phase = .awaitingVoice
        tts.stop()
    }

    // MARK: - Follow-up (追问 / interrupt)

    /// Interrupt the explanation to ask a free-form question. Streams the answer
    /// via the chat endpoint and appends it to the follow-up thread, then resumes
    /// teaching the current step.
    func askFollowUp(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tts.stop()
        followUps.append(TutorFollowUp(role: .user, text: trimmed, atSegmentIndex: currentIndex))
        isAnsweringFollowUp = true
        let resumePhase = phase
        phase = .answering

        // Seed an empty assistant turn we stream into.
        let assistant = TutorFollowUp(role: .assistant, text: "", atSegmentIndex: currentIndex)
        followUps.append(assistant)
        let assistantID = assistant.id

        let chatRequest = ChatRequest(
            turns: [ChatTurn(role: .user, text: contextualizedQuestion(trimmed))],
            context: LearnerContext(grade: request.grade, subjects: [request.subject]),
            kind: .tutor
        )

        // Tracked so `tearDown()`/`retry()` cancel an in-flight answer — otherwise the
        // stream keeps mutating model state (and re-starting TTS) after the view is gone.
        followUpTask = Task { [weak self] in
            guard let self else { return }
            var accumulated = ""
            do {
                for try await chunk in self.intelligence.chat(chatRequest) {
                    if Task.isCancelled { return }
                    accumulated += chunk.delta
                    self.updateFollowUp(id: assistantID, text: accumulated)
                    if chunk.isFinal { self.route = chunk.route }
                }
            } catch {
                accumulated = accumulated.isEmpty ? "我没太听清，换个说法再问我一次好吗？" : accumulated
                self.updateFollowUp(id: assistantID, text: accumulated)
            }
            if Task.isCancelled { return }
            self.isAnsweringFollowUp = false
            self.narrate(accumulated)
            // Resume the prior phase (teaching or checkpoint) after answering.
            if case .checkpoint = resumePhase, let cp = self.currentSegment?.checkpoint {
                self.activeCheckpoint = cp
                self.phase = .checkpoint
            } else {
                self.phase = .teaching
                self.markFinishedIfDone()
            }
            self.followUpTask = nil
        }
    }

    private func updateFollowUp(id: UUID, text: String) {
        guard let idx = followUps.firstIndex(where: { $0.id == id }) else { return }
        followUps[idx].text = text
    }

    private func contextualizedQuestion(_ q: String) -> String {
        guard let segment = currentSegment else { return q }
        let stepHint = segment.board.first(where: { $0.kind == .title || $0.kind == .bullet })?.content
        if let stepHint, !stepHint.isEmpty {
            return "关于“\(stepHint)”这一步，\(q)"
        }
        return q
    }

    // MARK: - TTS

    private func narrate(_ text: String) {
        guard ttsEnabled else { return }
        tts.stop()
        // AVSpeech default rate is 0.5; scale by pace, clamped to a natural range.
        let rate = Float(min(0.62, max(0.36, 0.5 * paceMultiplier)))
        let language = request.subject == .english ? "en-US" : "zh-CN"
        tts.speak(text, language: language, rate: rate)
    }

    func toggleTTS() {
        ttsEnabled.toggle()
        if !ttsEnabled { tts.stop() }
        else { repeatNarration() }
    }

    // MARK: - Intent mapping helper

    nonisolated static func transcriptMeansUnderstood(_ transcript: String) -> Bool {
        let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let confused = ["没懂", "不懂", "不会", "没听懂", "再讲", "重讲", "再来", "不明白", "没明白", "不太懂"]
        if confused.contains(where: { t.contains($0) }) { return false }
        // Default to "understood" for affirmatives or empty (the friendly default).
        return true
    }
}
