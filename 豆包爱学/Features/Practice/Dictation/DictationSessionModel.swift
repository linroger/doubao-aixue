//
//  DictationSessionModel.swift
//  豆包爱学 — Features/Practice/Dictation
//
//  The brain of a 听写 session. Owns the three phases (read-aloud → 默写 → 批改),
//  the read-aloud controls (语速 / 间隔 / 重复 / 上一个 / 下一个 / 自动播放), the typed /
//  手写 answers, the grading round-trip through intelligence.gradeDictation, and
//  the persistence of a DictationResult plus每个错字 → MistakeItem.
//
//  MainActor by default. TTS has no completion callback, so 自动播放 is driven by a
//  Task-based timer keyed on 语速 + 间隔. A "重测错词" round narrows the active entries
//  to the previously-missed words while keeping the original total for the result.
//

import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class DictationSessionModel {

    enum Phase: Equatable {
        case reading        // 老师念词
        case writing        // 孩子默写
        case grading        // 批改中
        case result         // 出分
    }

    // MARK: Stored configuration / dependencies

    let listID: UUID
    let listName: String
    let language: Subject
    /// The full word list (never mutated) — defines the canonical order & total.
    let allEntries: [DictationEntry]

    private let intelligence: any IntelligenceService
    private let ocr: OCRService
    private let tts: TTSService
    private let modelContext: ModelContext

    // MARK: Session state

    private(set) var phase: Phase = .reading

    /// Entries active this round. A 重测错词 round shrinks this to the missed words.
    private(set) var activeEntries: [DictationEntry]
    /// True when this round only covers previously-wrong words.
    private(set) var isRetryRound = false

    /// Index into `activeEntries` of the word currently being read.
    var currentIndex = 0

    /// Typed / recognised answers, keyed by entry id, for the writing phase.
    var answers: [String: String] = [:]

    /// Grading output.
    private(set) var grading: DictationGrading?
    private(set) var gradeError: String?

    // MARK: Read-aloud controls

    enum Speed: String, CaseIterable, Identifiable {
        case slow, normal, fast
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .slow: "慢速"
            case .normal: "正常"
            case .fast: "快速"
            }
        }
        var rate: Float {
            switch self {
            case .slow: 0.38
            case .normal: 0.48
            case .fast: 0.56
            }
        }
        /// Estimated seconds to read one short word at this speed (drives auto-advance).
        var estimatedReadSeconds: Double {
            switch self {
            case .slow: 1.6
            case .normal: 1.2
            case .fast: 0.9
            }
        }
    }

    var speed: Speed = .normal
    /// Gap (秒) inserted after each word before auto-advancing.
    var gapSeconds: Double = 3
    /// Times each word is repeated when read.
    var repeatCount: Int = 1
    /// Whether reading auto-advances to the next word.
    var autoAdvance: Bool = true

    private(set) var isAutoPlaying = false
    private var autoPlayTask: Task<Void, Never>?

    // MARK: Init

    init(list: DictationList,
         intelligence: any IntelligenceService,
         ocr: OCRService,
         tts: TTSService,
         modelContext: ModelContext) {
        self.listID = list.id
        self.listName = list.name
        self.language = list.language
        self.allEntries = list.entries
        self.activeEntries = list.entries
        self.intelligence = intelligence
        self.ocr = ocr
        self.tts = tts
        self.modelContext = modelContext
    }

    // MARK: Derived

    var ttsLanguageCode: String { language == .english ? "en-US" : "zh-CN" }
    var totalThisRound: Int { activeEntries.count }
    var currentEntry: DictationEntry? {
        guard activeEntries.indices.contains(currentIndex) else { return nil }
        return activeEntries[currentIndex]
    }
    var isLastEntry: Bool { currentIndex >= activeEntries.count - 1 }
    var isFirstEntry: Bool { currentIndex <= 0 }

    // MARK: Read-aloud actions

    /// Speak the current word `repeatCount` times.
    func speakCurrent() {
        guard let entry = currentEntry else { return }
        // For repeats we lean on a single utterance enqueue per repeat; the
        // synthesizer queues them sequentially.
        for _ in 0..<max(1, repeatCount) {
            tts.speak(entry.text, language: ttsLanguageCode, rate: speed.rate)
        }
        HapticEngine.play(.light)
    }

    func goPrevious() {
        stopAutoPlay()
        tts.stop()
        currentIndex = max(0, currentIndex - 1)
        speakCurrent()
    }

    func goNext() {
        stopAutoPlay()
        tts.stop()
        if !isLastEntry {
            currentIndex += 1
            speakCurrent()
        }
    }

    /// Start reading from the current index, auto-advancing if enabled.
    func startReading() {
        guard phase == .reading else { return }
        if autoAdvance {
            startAutoPlay()
        } else {
            speakCurrent()
        }
    }

    func toggleAutoPlay() {
        if isAutoPlaying {
            stopAutoPlay()
            tts.stop()
        } else {
            startAutoPlay()
        }
    }

    private func startAutoPlay() {
        autoPlayTask?.cancel()
        isAutoPlaying = true
        autoPlayTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard self.activeEntries.indices.contains(self.currentIndex) else { break }
                self.speakCurrent()
                // Reading time (scaled by repeats) + the configured gap.
                let readTime = self.speed.estimatedReadSeconds * Double(max(1, self.repeatCount))
                let wait = readTime + self.gapSeconds
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                if Task.isCancelled { break }
                if self.isLastEntry {
                    break
                }
                self.currentIndex += 1
            }
            self.isAutoPlaying = false
        }
    }

    func stopAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = nil
        isAutoPlaying = false
    }

    // MARK: Phase transitions

    /// Move from read-aloud to writing. Pre-seeds empty answers so binding is stable.
    func beginWriting() {
        stopAutoPlay()
        tts.stop()
        for entry in activeEntries where answers[entry.id] == nil {
            answers[entry.id] = ""
        }
        phase = .writing
    }

    /// Back to reading (e.g. "再听一遍").
    func backToReading() {
        currentIndex = 0
        phase = .reading
    }

    func answer(for entry: DictationEntry) -> String {
        answers[entry.id] ?? ""
    }

    /// Recognise handwriting strokes (iOS) into the answer for an entry.
    func recognizeHandwriting(_ imageData: Data, for entry: DictationEntry) async {
        let text = await ocr.recognizeText(in: imageData)
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            answers[entry.id] = cleaned
            HapticEngine.play(.success)
        } else {
            HapticEngine.play(.warning)
        }
    }

    // MARK: Grading

    func submitForGrading() async {
        stopAutoPlay()
        tts.stop()
        phase = .grading
        gradeError = nil
        let expected = activeEntries.map(\.text)
        let written = activeEntries.map { answers[$0.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        do {
            let result = try await intelligence.gradeDictation(
                DictationGradeRequest(expected: expected, written: written))
            grading = result
            phase = .result
            persistResult(result)
            HapticEngine.play(result.correct == result.total ? .success : .warning)
        } catch {
            gradeError = "批改没成功，请检查后再试一次。"
            phase = .writing
            HapticEngine.play(.error)
        }
    }

    /// The entries the child got wrong this round (canonical entries, for retry).
    var wrongEntries: [DictationEntry] {
        guard let grading else { return [] }
        let wrongWords = Set(grading.results.filter { !$0.isCorrect }.map(\.expected))
        return activeEntries.filter { wrongWords.contains($0.text) }
    }

    /// Per-word results, paired back to the canonical entry for readings / meanings.
    var resultRows: [ResultRow] {
        guard let grading else { return [] }
        return grading.results.enumerated().map { idx, r in
            let entry = activeEntries.indices.contains(idx) ? activeEntries[idx] : nil
            return ResultRow(id: r.id, expected: r.expected, written: r.written,
                             isCorrect: r.isCorrect,
                             reading: entry?.reading ?? "", meaning: entry?.meaning ?? "")
        }
    }

    struct ResultRow: Identifiable, Hashable {
        let id: String
        let expected: String
        let written: String
        let isCorrect: Bool
        let reading: String
        let meaning: String
    }

    /// Start a fresh round limited to the missed words.
    func retryWrongWords() {
        let wrong = wrongEntries
        guard !wrong.isEmpty else { return }
        activeEntries = wrong
        isRetryRound = true
        currentIndex = 0
        answers = [:]
        grading = nil
        gradeError = nil
        phase = .reading
    }

    /// Restart the whole list from scratch.
    func restartAll() {
        activeEntries = allEntries
        isRetryRound = false
        currentIndex = 0
        answers = [:]
        grading = nil
        gradeError = nil
        phase = .reading
    }

    // MARK: Persistence

    private func persistResult(_ grading: DictationGrading) {
        let result = DictationResult()
        result.listID = listID
        result.listName = listName
        result.total = grading.total
        result.correct = grading.correct
        result.wrongWords = grading.results.filter { !$0.isCorrect }.map(\.expected)
        modelContext.insert(result)

        // Fold每个错字 into the 错题本 so review surfaces them later.
        for r in grading.results where !r.isCorrect && !r.expected.isEmpty {
            let item = MistakeItem()
            item.subject = language
            item.questionText = dictationPrompt(for: r.expected)
            item.studentAnswer = r.written
            item.correctAnswer = r.expected
            item.errorType = .careless
            item.errorReason = "听写默写错误"
            item.mastery = .new
            modelContext.insert(item)
        }
        try? modelContext.save()
    }

    private func dictationPrompt(for word: String) -> String {
        language == .english ? "英语听写：spell「\(word)」" : "语文听写：写出「\(word)」"
    }
}
