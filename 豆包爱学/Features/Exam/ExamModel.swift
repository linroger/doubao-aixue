//
//  ExamModel.swift
//  豆包爱学 — Features/Exam
//
//  模拟测验 (timed practice exam). The view model that turns a chosen subject +
//  question count + time limit into a timed quiz and runs it end-to-end:
//
//    1. setup    — pick subject / 题量 / 时长. Estimated effort previewed.
//    2. assemble — seed from `ContentCatalog.sampleProblems` for the subject, then
//                  top up with `intelligence.similarProblems` (`GeneratedProblem`) so
//                  the paper always reaches the requested count with fresh items.
//    3. running  — one question per screen: a countdown timer, a progress bar, the
//                  question (`MathText` for STEM), a typed (iOS PencilKit) answer,
//                  上一题 / 下一题, and 交卷.
//    4. timeUp   — the countdown reached 0; the paper is auto-submitted.
//    5. graded   — auto-graded report: score ring, per-question ✓/✗ with the
//                  revealed `SolutionStep`s, 加入错题本 for wrong items (inserts a
//                  `MistakeItem`), and a persisted `PracticeSession` + attempts.
//
//  Pure value helpers (`ExamConfig`, `ExamQuestion`, `ExamOutcome`) are `nonisolated`;
//  the model is `@MainActor @Observable`. SwiftData is read by the view (@Query); the
//  model never holds a `ModelContext` — persistence is handed a context to write into.
//

import SwiftUI
import SwiftData

// MARK: - Config (pure)

/// A single immutable question on the assembled paper. Built from a catalog problem
/// or a generated one, but the runner/grader only ever see this uniform shape.
nonisolated struct ExamQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let subject: Subject
    let prompt: String
    let answer: String
    let steps: [SolutionStep]
    let knowledgePointID: String

    /// MCQ option labels (e.g. "A".."D") parsed out of the prompt, used only to hint
    /// the answer keyboard; correctness still flows through `ExamAnswerChecker`.
    var isLikelyChoice: Bool {
        answer.count == 1 && answer.uppercased().first.map { ("A"..."Z").contains($0) } == true
    }
}

/// The countdown options offered on the setup screen (minutes).
nonisolated enum ExamDuration: Int, CaseIterable, Identifiable, Sendable {
    case quick = 5
    case standard = 10
    case full = 20

    var id: Int { rawValue }
    var minutes: Int { rawValue }
    var seconds: Int { rawValue * 60 }

    var displayName: String { "\(rawValue) 分钟" }
    var caption: String {
        switch self {
        case .quick:    "快速热身"
        case .standard: "常规小测"
        case .full:     "完整模考"
        }
    }
}

// MARK: - Answer checking (pure)

/// Normalizes and compares a typed answer against the expected answer. Lenient on
/// whitespace, full/half-width punctuation, choice-letter case, and numeric form so a
/// correct answer is never failed for cosmetic differences.
nonisolated enum ExamAnswerChecker {

    static func isCorrect(_ typed: String, expected: String) -> Bool {
        let a = normalize(typed)
        let b = normalize(expected)
        guard !a.isEmpty else { return false }
        if a == b { return true }
        // Single-letter MCQ: compare just the leading letter the learner picked.
        if b.count == 1, let first = a.first(where: { $0.isLetter }) {
            return String(first) == b
        }
        // Numeric equivalence (e.g. "0.5" vs "0.50").
        if let na = Double(a), let nb = Double(b) {
            return abs(na - nb) < 0.0001
        }
        // The expected answer often embeds the value in a sentence (e.g. "x = 3" or
        // "40 平方厘米"). Accept a typed bare value that the expected answer contains.
        return b.contains(a) && a.count >= max(1, b.count / 3)
    }

    static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        t = t.split(whereSeparator: { $0.isWhitespace }).joined()
        let map: [Character: Character] = [
            "，": ",", "。": ".", "：": ":", "；": ";",
            "（": "(", "）": ")", "＝": "=", "×": "*", "÷": "/",
            "－": "-", "＋": "+", "　": " "
        ]
        t = String(t.map { map[$0] ?? $0 })
        for prefix in ["答案是", "答案为", "答案:", "answer:", "ans:"] where t.hasPrefix(prefix) {
            t.removeFirst(prefix.count)
        }
        return t
    }
}

// MARK: - Per-question outcome (pure)

/// What the learner did on one question, captured at grade time so the report and the
/// persisted `PracticeAttempt`/`MistakeItem` all read from one immutable source.
nonisolated struct ExamOutcome: Identifiable, Hashable, Sendable {
    let questionID: String
    let subject: Subject
    let prompt: String
    let typedAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
    let steps: [SolutionStep]
    let knowledgePointID: String

    var id: String { questionID }
    var wasAnswered: Bool { !typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Flow phase

/// The high-level screen `ExamView` shows.
enum ExamPhase: Equatable {
    case setup
    case running
    case timeUp     // transient bridge — auto-grades on appear of the time-up sheet
    case graded
}

// MARK: - View model

@MainActor
@Observable
final class ExamModel {

    // MARK: Configuration

    /// Subjects the learner can sit an exam in (profile subjects, else all).
    var availableSubjects: [Subject] = []
    var selectedSubject: Subject = .math
    var requestedCount: Int = 5
    var duration: ExamDuration = .standard

    /// The learner's grade, used for generation requests (set from profile by the view).
    var grade: GradeLevel = .g5

    // MARK: Flow state

    var phase: ExamPhase = .setup

    /// Drives the assembly step (loading / error / the assembled paper).
    var assembly: ViewState<[ExamQuestion]> = .idle

    // MARK: Runner state

    private(set) var questions: [ExamQuestion] = []
    var currentIndex: Int = 0

    /// Typed answers, one slot per question (kept aligned with `questions`).
    var answers: [String] = []

    /// Seconds remaining on the countdown; drained by `tick()`.
    private(set) var secondsRemaining: Int = 0
    private(set) var totalSeconds: Int = 0

    // MARK: Graded state

    private(set) var outcomes: [ExamOutcome] = []
    /// Whether the time ran out (vs. a manual 交卷) — surfaced in the report copy.
    private(set) var didTimeOut = false
    /// Question IDs the learner has pushed into the 错题本 (so the button is idempotent).
    private(set) var savedMistakeIDs: Set<String> = []

    private var startedAt: Date = .now

    // MARK: Derived

    var currentQuestion: ExamQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var currentAnswer: String {
        get { answers.indices.contains(currentIndex) ? answers[currentIndex] : "" }
        set { if answers.indices.contains(currentIndex) { answers[currentIndex] = newValue } }
    }

    var progress: Double {
        questions.isEmpty ? 0 : Double(currentIndex + 1) / Double(questions.count)
    }

    var answeredCount: Int {
        answers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var isLastQuestion: Bool { currentIndex >= questions.count - 1 }
    var isFirstQuestion: Bool { currentIndex <= 0 }

    var correctCount: Int { outcomes.filter(\.isCorrect).count }

    var accuracy: Double {
        outcomes.isEmpty ? 0 : Double(correctCount) / Double(outcomes.count)
    }

    var allCorrect: Bool { !outcomes.isEmpty && correctCount == outcomes.count }

    /// 0…100 score for the ring (rounded percentage of correct answers).
    var scorePercent: Int { Int((accuracy * 100).rounded()) }

    /// MM:SS countdown string for the timer chip.
    var timeRemainingLabel: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// True in the final stretch (≤ 60s) so the timer can turn warning-red.
    var isTimeCritical: Bool { secondsRemaining <= 60 && secondsRemaining > 0 }

    var estimatedMinutes: Int { duration.minutes }

    // MARK: - Setup

    /// Configure the subject list + defaults from the learner profile. Idempotent: keeps
    /// a valid prior subject selection across re-runs.
    func configure(profileGrade: GradeLevel, profileSubjects: [Subject]) {
        grade = profileGrade
        let subjects = profileSubjects.isEmpty ? Subject.allCases : profileSubjects
        availableSubjects = subjects
        if !subjects.contains(selectedSubject) {
            selectedSubject = subjects.first ?? .math
        }
    }

    // MARK: - Assembly

    /// Build the paper: catalog problems for the subject first (deterministic, instant),
    /// then top up to `requestedCount` with generated similar problems. Starts the runner.
    func assemble(using intelligence: any IntelligenceService) async {
        assembly = .loading

        // 1) Seed from the catalog for the chosen subject.
        var built: [ExamQuestion] = ContentCatalog.sampleProblems
            .filter { $0.subject == selectedSubject }
            .map { problem in
                ExamQuestion(
                    id: "catalog-\(problem.id.uuidString)",
                    subject: problem.subject,
                    prompt: problem.text,
                    answer: problem.answer,
                    steps: [],
                    knowledgePointID: ""
                )
            }

        // 2) Top up with generated similar problems until we hit the requested count.
        let need = max(0, requestedCount - built.count)
        if need > 0 {
            do {
                let reference = built.first?.prompt ?? selectedSubject.displayName
                let request = SimilarRequest(
                    subject: selectedSubject,
                    knowledgePoints: [],
                    referenceText: reference,
                    count: need,
                    grade: grade
                )
                let generated = try await intelligence.similarProblems(request)
                built.append(contentsOf: generated.map { g in
                    ExamQuestion(
                        id: "gen-\(g.id)",
                        subject: selectedSubject,
                        prompt: g.question,
                        answer: g.answer,
                        steps: g.steps,
                        knowledgePointID: g.knowledgePointID
                    )
                })
            } catch {
                // Generation is a top-up, not a hard dependency: if it fails but we still
                // seeded at least one catalog question, run with what we have. Only error
                // out when there is genuinely nothing to sit.
                if built.isEmpty {
                    assembly = .error(message: "试卷生成失败了，请稍后再试。")
                    return
                }
            }
        }

        // Trim to the requested count (catalog + generated may overshoot) and guard empty.
        let paper = Array(built.prefix(max(requestedCount, 1)))
        guard !paper.isEmpty else {
            assembly = .empty(message: "这个学科暂时没有可用的题目，换一个试试。")
            return
        }

        questions = paper
        answers = Array(repeating: "", count: paper.count)
        currentIndex = 0
        outcomes = []
        savedMistakeIDs = []
        didTimeOut = false
        totalSeconds = duration.seconds
        secondsRemaining = duration.seconds
        startedAt = .now
        assembly = .loaded(paper)
        phase = .running
        HapticEngine.play(.light)
    }

    // MARK: - Runner navigation

    func goNext() {
        guard !isLastQuestion else { return }
        currentIndex += 1
        HapticEngine.play(.selection)
    }

    func goPrevious() {
        guard !isFirstQuestion else { return }
        currentIndex -= 1
        HapticEngine.play(.selection)
    }

    func jump(to index: Int) {
        guard questions.indices.contains(index) else { return }
        currentIndex = index
    }

    // MARK: - Timer

    /// Advance the countdown by one second. When it hits 0, the paper is auto-submitted
    /// (`timeUp` phase). Called once per second by the running view's `TimelineView`/timer.
    func tick() {
        guard phase == .running, secondsRemaining > 0 else { return }
        secondsRemaining -= 1
        if secondsRemaining == 0 {
            didTimeOut = true
            phase = .timeUp
            HapticEngine.play(.warning)
        }
    }

    // MARK: - Grading

    /// Manual 交卷 from the runner.
    func submit() {
        guard phase == .running else { return }
        didTimeOut = false
        gradePaper()
    }

    /// Called from the time-up bridge to roll into the graded report.
    func gradeAfterTimeout() {
        gradePaper()
    }

    /// Auto-grade every question against its expected answer and move to the report.
    /// (Named `gradePaper` to avoid colliding with the `grade` GradeLevel property.)
    private func gradePaper() {
        outcomes = questions.enumerated().map { index, q in
            let typed = answers.indices.contains(index) ? answers[index] : ""
            let correct = ExamAnswerChecker.isCorrect(typed, expected: q.answer)
            return ExamOutcome(
                questionID: q.id,
                subject: q.subject,
                prompt: q.prompt,
                typedAnswer: typed.trimmingCharacters(in: .whitespacesAndNewlines),
                correctAnswer: q.answer,
                isCorrect: correct,
                steps: q.steps,
                knowledgePointID: q.knowledgePointID
            )
        }
        phase = .graded
        HapticEngine.play(allCorrect ? .success : .light)
    }

    /// Wrong questions, for the 错题本 prompt and the recap's failure section.
    var wrongOutcomes: [ExamOutcome] { outcomes.filter { !$0.isCorrect } }

    // MARK: - Persistence

    /// On reaching the report: insert a `PracticeSession` + one `PracticeAttempt` per
    /// question, log an `ActivityLog`, and nudge mastery for any knowledge points the
    /// paper touched. Idempotent — only writes once per graded paper.
    private(set) var saved = false

    func persistResults(context: ModelContext, existingMasteries: [MasteryRecord]) {
        guard !saved, !outcomes.isEmpty else { return }

        // 1) Session + attempts.
        let session = PracticeSession()
        session.subject = selectedSubject
        session.title = "模拟测验 · \(selectedSubject.displayName)"
        session.kindRaw = "exam"
        session.targetKnowledgePointIDs = Array(
            Set(outcomes.map(\.knowledgePointID).filter { !$0.isEmpty })
        )
        session.totalCount = outcomes.count
        session.correctCount = correctCount
        session.estMinutes = duration.minutes
        session.completed = true
        session.completedAt = .now
        context.insert(session)

        for outcome in outcomes {
            let attempt = PracticeAttempt()
            attempt.questionText = outcome.prompt
            attempt.answer = outcome.typedAnswer
            attempt.correctAnswer = outcome.correctAnswer
            attempt.isCorrect = outcome.isCorrect
            attempt.knowledgePointID = outcome.knowledgePointID
            attempt.session = session
            context.insert(attempt)
        }

        // 2) Activity log so the 学习报告 picks up the time spent.
        let elapsed = Date.now.timeIntervalSince(startedAt)
        let log = ActivityLog()
        log.kindRaw = "practice"
        log.subject = selectedSubject
        log.detail = "模拟测验 \(correctCount)/\(outcomes.count)"
        log.minutes = max(1, (elapsed / 60).rounded())
        log.date = .now
        context.insert(log)

        // 3) Mastery nudge for knowledge points the generated questions tagged.
        let touchedIDs = Set(outcomes.map(\.knowledgePointID).filter { !$0.isEmpty })
        for id in touchedIDs {
            let related = outcomes.filter { $0.knowledgePointID == id }
            guard !related.isEmpty else { continue }
            let pointAccuracy = Double(related.filter(\.isCorrect).count) / Double(related.count)
            let record: MasteryRecord
            if let existing = existingMasteries.first(where: { $0.knowledgePointID == id }) {
                record = existing
            } else {
                let fresh = MasteryRecord()
                fresh.knowledgePointID = id
                fresh.subject = selectedSubject
                fresh.score = pointAccuracy
                context.insert(fresh)
                record = fresh
            }
            record.score = min(1, max(0, record.score * 0.7 + pointAccuracy * 0.3))
            record.attempts += related.count
            record.correctCount += related.filter(\.isCorrect).count
            record.lastUpdated = .now
        }

        try? context.save()
        saved = true
    }

    /// Add one wrong question to the 错题本 as a `MistakeItem`. Idempotent per question.
    func addToMistakes(_ outcome: ExamOutcome, context: ModelContext) {
        guard !savedMistakeIDs.contains(outcome.questionID) else { return }
        let item = MistakeItem()
        item.subject = outcome.subject
        item.questionText = outcome.prompt
        item.studentAnswer = outcome.wasAnswered ? outcome.typedAnswer : "未作答"
        item.correctAnswer = outcome.correctAnswer
        item.errorReason = outcome.wasAnswered ? "答案有误，需巩固。" : "限时内未作答，需加强训练。"
        item.errorType = outcome.wasAnswered ? .concept : .careless
        item.mastery = .weak
        item.knowledgePointIDs = outcome.knowledgePointID.isEmpty ? [] : [outcome.knowledgePointID]
        item.steps = outcome.steps
        item.createdAt = .now
        item.nextReviewAt = .now
        context.insert(item)
        try? context.save()
        savedMistakeIDs.insert(outcome.questionID)
        HapticEngine.play(.success)
    }

    func hasSavedMistake(_ outcome: ExamOutcome) -> Bool {
        savedMistakeIDs.contains(outcome.questionID)
    }

    // MARK: - Reset

    /// Start a brand-new exam (再考一次) — back to the setup screen.
    func reset() {
        phase = .setup
        assembly = .idle
        questions = []
        answers = []
        outcomes = []
        savedMistakeIDs = []
        currentIndex = 0
        secondsRemaining = 0
        totalSeconds = 0
        didTimeOut = false
        saved = false
    }
}
