//
//  LessonPlayerModel.swift
//  豆包爱学 — Features/Courses/Classroom
//
//  View model for the 豆包课堂 lesson player (RESEARCH §4.3 / F23–F27). Unlike the
//  live 豆包老师 tutor (which *streams* segments from
//  `intelligence.tutorSession`), a 课程 is an authored 课件: its [TutorSegment]
//  script is already stored on `CourseEntity.segments`. This model therefore
//  drives a *fixed* sequence of segments as 情景短片 + 知识点精讲:
//
//    • progressively reveals each segment's 动态板书 (BoardElements) one element
//      at a time, synced with TTS narration;
//    • pauses at a TutorCheckpoint for an inline 互动习题 ("是否听懂了 / 选一选");
//    • supports replay / pace control / chapter (segment) jumps;
//    • persists `LessonProgress` (last segment + completion + quiz score) to
//      SwiftData so the student resumes where they left off.
//
//  MainActor-isolated (the default). It never touches the network — narration
//  comes from the injected `TTSService` and content is already on the model.
//

import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class LessonPlayerModel {

    // MARK: Inputs
    let courseID: UUID
    let segments: [TutorSegment]

    // MARK: Playback state
    /// Index of the segment (章节) currently on the board.
    private(set) var currentIndex: Int = 0
    /// How many BoardElements of the current segment are revealed (progressive 板书).
    private(set) var revealedElementCount: Int = 0
    /// The checkpoint (互动习题) attached to the current segment, when paused on it.
    private(set) var activeCheckpoint: TutorCheckpoint?
    /// The student's picked option for the active checkpoint (nil until answered).
    private(set) var checkpointSelection: Int?
    /// True once the whole course has been played to the end.
    private(set) var isFinished = false
    /// Number of checkpoints answered correctly (persisted to LessonProgress).
    private(set) var quizCorrect = 0
    /// Indices whose checkpoint has already been scored (avoid double counting on replay).
    private var scoredCheckpointIndices: Set<Int> = []

    // MARK: Settings
    var ttsEnabled = true
    /// Narration pace, mapped to AVSpeechUtterance rate. 0.75x … 1.5x.
    var paceMultiplier: Double = 1.0 {
        didSet { paceMultiplier = min(1.5, max(0.75, paceMultiplier)) }
    }

    // MARK: Convenience accessors
    var currentSegment: TutorSegment? {
        segments.indices.contains(currentIndex) ? segments[currentIndex] : nil
    }
    var visibleBoardElements: [BoardElement] {
        guard let board = currentSegment?.board else { return [] }
        return Array(board.prefix(revealedElementCount))
    }
    /// Whether the current segment is fully revealed (board done + no pending checkpoint).
    var isCurrentSegmentComplete: Bool {
        guard let segment = currentSegment else { return false }
        let boardDone = revealedElementCount >= segment.board.count
        let checkpointDone = segment.checkpoint == nil || checkpointSelection != nil
        return boardDone && checkpointDone
    }
    var canAdvance: Bool { currentIndex < segments.count - 1 }
    var hasPreviousSegment: Bool { currentIndex > 0 }
    /// Progress through the course (0…1), counting the current segment as in-flight.
    var progress: Double {
        guard !segments.isEmpty else { return 0 }
        if isFinished { return 1 }
        return min(1, Double(currentIndex) / Double(segments.count))
    }
    var isWaitingOnCheckpoint: Bool { activeCheckpoint != nil && checkpointSelection == nil }

    // MARK: Private
    private var revealTask: Task<Void, Never>?
    private let tts: TTSService

    init(courseID: UUID, segments: [TutorSegment], tts: TTSService) {
        self.courseID = courseID
        self.segments = segments
        self.tts = tts
    }

    // MARK: - Lifecycle

    /// Begin the lesson at `startIndex` (resume point from LessonProgress).
    func start(at startIndex: Int) {
        guard !segments.isEmpty else { return }
        currentIndex = min(max(0, startIndex), segments.count - 1)
        presentCurrentSegment()
    }

    func tearDown() {
        revealTask?.cancel(); revealTask = nil
        tts.stop()
    }

    // MARK: - Presenting a segment

    private func presentCurrentSegment() {
        guard let segment = currentSegment else { return }
        activeCheckpoint = nil
        checkpointSelection = nil
        revealedElementCount = 0
        isFinished = false

        narrate(segment.narration)
        revealBoardElements(count: segment.board.count) { [weak self] in
            guard let self else { return }
            if let checkpoint = segment.checkpoint {
                self.enterCheckpoint(checkpoint)
            } else {
                self.markFinishedIfLast()
            }
        }
    }

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
        checkpointSelection = nil
        HapticEngine.play(.selection)
        narrate(checkpoint.prompt)
    }

    private func markFinishedIfLast() {
        if currentIndex >= segments.count - 1 {
            isFinished = true
            HapticEngine.play(.success)
        }
    }

    // MARK: - Checkpoint (互动习题) resolution

    /// Resolve the inline interactive question. Records correctness once per index.
    func answerCheckpoint(_ optionIndex: Int) {
        guard let checkpoint = activeCheckpoint, checkpointSelection == nil else { return }
        checkpointSelection = optionIndex
        let correct = optionIndex == checkpoint.answerIndex
        if correct {
            if scoredCheckpointIndices.insert(currentIndex).inserted { quizCorrect += 1 }
            HapticEngine.play(.success)
        } else {
            HapticEngine.play(.warning)
        }
        markFinishedIfLast()
    }

    // MARK: - Navigation / pacing

    /// Advance to the next chapter ("继续学习").
    func advance() {
        guard currentIndex < segments.count - 1 else {
            markFinishedIfLast(); return
        }
        currentIndex += 1
        presentCurrentSegment()
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        presentCurrentSegment()
    }

    /// Re-teach the current chapter ("再讲一遍").
    func replayCurrent() {
        HapticEngine.play(.light)
        presentCurrentSegment()
    }

    /// Jump to a specific chapter from the marker rail / transcript.
    func jump(to index: Int) {
        guard segments.indices.contains(index) else { return }
        currentIndex = index
        presentCurrentSegment()
    }

    /// Restart the whole course from the beginning.
    func restart() {
        scoredCheckpointIndices.removeAll()
        quizCorrect = 0
        jump(to: 0)
    }

    /// Re-read the current narration aloud without re-animating the board.
    func repeatNarration() {
        guard let segment = currentSegment else { return }
        narrate(activeCheckpoint?.prompt ?? segment.narration)
    }

    // MARK: - TTS

    private func narrate(_ text: String) {
        guard ttsEnabled, !text.isEmpty else { return }
        tts.stop()
        let rate = Float(min(0.62, max(0.36, 0.5 * paceMultiplier)))
        tts.speak(text, language: "zh-CN", rate: rate)
    }

    func toggleTTS() {
        ttsEnabled.toggle()
        if !ttsEnabled { tts.stop() } else { repeatNarration() }
    }
}
