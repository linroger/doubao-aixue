//
//  DrillModel.swift
//  豆包爱学 — Features/Practice/Drill
//
//  举一反三 / 靶向练习 (RESEARCH F47/F48). The view model that turns the learner's
//  weakest `MasteryRecord`s into a focused, generated practice set and runs it as a
//  question-by-question runner. It is the single source of truth for the flow:
//
//    1. setup     — pick a target (auto = weakest mastery point) + subject/KP picker,
//                   estimate minutes via `StudyPlanner`.
//    2. generate  — `intelligence.similarProblems` → `[GeneratedProblem]`.
//    3. run       — show one `GeneratedProblem` at a time, accept a typed answer,
//                   check it, reveal the `SolutionStep`s, advance.
//    4. finish    — update the `MasteryRecord` for the target KP, insert a
//                   `PracticeSession` + one `PracticeAttempt` per question, celebrate.
//
//  Pure value helpers (`DrillTarget`, answer normalization) are `nonisolated`; the
//  model is `@MainActor @Observable`. SwiftData is read by the view (@Query) and the
//  weak-point list + persistence are handed in so the model never holds a context.
//

import SwiftUI
import SwiftData

// MARK: - Target (pure)

/// A single practice target: one knowledge point in one subject with its current
/// mastery score (0…1). Built from a `MasteryRecord` (auto pick) or chosen in the
/// subject/KP picker. Pure value type so the setup screen stays declarative.
nonisolated struct DrillTarget: Identifiable, Hashable, Sendable {
    let id: String          // knowledge point id
    let name: String
    let subject: Subject
    let score: Double       // current mastery 0…1
    let grade: GradeLevel

    /// The mastery bucket used for copy + tint on the setup card.
    var state: MasteryState {
        switch score {
        case ..<0.2: .new
        case ..<0.5: .weak
        case ..<0.85: .developing
        default: .mastered
        }
    }

    var knowledgeRef: KnowledgeRef {
        KnowledgeRef(id: id, name: name, subject: subject)
    }
}

// MARK: - Answer checking (pure)

/// Normalizes and compares a typed answer against the expected answer. Lenient on
/// whitespace, full/half-width punctuation, and common math equivalences so the
/// runner doesn't punish a correct answer for cosmetic differences.
nonisolated enum DrillAnswerChecker {

    static func isCorrect(_ typed: String, expected: String) -> Bool {
        let a = normalize(typed)
        let b = normalize(expected)
        guard !a.isEmpty else { return false }
        if a == b { return true }
        // Numeric equivalence (e.g. "0.5" vs "0.50", "1/2" handled as strings only).
        if let na = Double(a), let nb = Double(b) {
            return abs(na - nb) < 0.0001
        }
        // The expected answer often embeds the value in a sentence (e.g. "x = 3").
        // Accept a typed bare value that appears as a standalone token.
        return b.contains(a) && a.count >= max(1, b.count / 3)
    }

    static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Collapse internal whitespace.
        t = t.split(whereSeparator: { $0.isWhitespace }).joined()
        // Fold common full-width / equivalent characters to a canonical form.
        let map: [Character: Character] = [
            "，": ",", "。": ".", "：": ":", "；": ";",
            "（": "(", "）": ")", "＝": "=", "×": "*", "÷": "/",
            "－": "-", "＋": "+", "　": " "
        ]
        t = String(t.map { map[$0] ?? $0 })
        // Drop a leading "answer is" style prefix that mock data sometimes adds.
        for prefix in ["答案是", "答案为", "答案:", "answer:", "ans:"] where t.hasPrefix(prefix) {
            t.removeFirst(prefix.count)
        }
        return t
    }
}

// MARK: - Flow phase

/// The high-level screen the `DrillView` shows. The runner owns its own per-question
/// sub-state (typed answer, reveal) inside `DrillModel`.
enum DrillPhase: Equatable {
    case setup
    case running
    case finished
}

// MARK: - View model

@MainActor
@Observable
final class DrillModel {

    // MARK: Configuration

    /// Available targets (weakest first), built from mastery records + catalog.
    var targets: [DrillTarget] = []

    /// The currently chosen target. Defaults to the weakest once `targets` loads.
    var selectedTarget: DrillTarget?

    /// How many problems to generate for this session.
    var requestedCount: Int = 5

    /// The learner's grade, used for generation requests (set from profile by the view).
    var grade: GradeLevel = .g5

    // MARK: Flow state

    var phase: DrillPhase = .setup

    /// Drives the generation step (loading spinner / error / the problem list).
    var generation: ViewState<[GeneratedProblem]> = .idle

    // MARK: Runner state (per session)

    private(set) var problems: [GeneratedProblem] = []
    var currentIndex: Int = 0

    /// The typed answer for the current problem (bound to the input field).
    var typedAnswer: String = ""

    /// Whether the current problem has been checked (answer locked, steps revealed).
    var hasChecked: Bool = false

    /// Per-problem outcome, captured at check time, used for results + persistence.
    private(set) var outcomes: [DrillOutcome] = []

    /// Wall-clock start of the current problem, for `timeSpent` on the attempt.
    private var questionStartedAt: Date = .now

    // MARK: Derived

    var estimatedMinutes: Int {
        StudyPlanner.estimatedMinutes(forTargets: requestedCount)
    }

    var currentProblem: GeneratedProblem? {
        problems.indices.contains(currentIndex) ? problems[currentIndex] : nil
    }

    /// True after the current answer is checked AND correct.
    var currentIsCorrect: Bool {
        outcomes.indices.contains(currentIndex) ? outcomes[currentIndex].isCorrect : false
    }

    var progress: Double {
        problems.isEmpty ? 0 : Double(currentIndex) / Double(problems.count)
    }

    var correctCount: Int { outcomes.filter(\.isCorrect).count }

    var accuracy: Double {
        outcomes.isEmpty ? 0 : Double(correctCount) / Double(outcomes.count)
    }

    var allCorrect: Bool { !outcomes.isEmpty && correctCount == outcomes.count }

    var isLastProblem: Bool { currentIndex >= problems.count - 1 }

    // MARK: - Setup

    /// Build the target list from mastery records (weakest first) and back-fill from
    /// the catalog so the picker is never empty even on a brand-new account.
    func configure(masteries: [MasteryRecord],
                   knowledgePoints: [KnowledgePointEntity],
                   profileGrade: GradeLevel,
                   profileSubjects: [Subject],
                   preselected: String? = nil) {
        grade = profileGrade

        // Name lookup: prefer the DB knowledge graph, fall back to the seed catalog.
        var nameByID: [String: (name: String, subject: Subject, grade: GradeLevel)] = [:]
        for kp in knowledgePoints {
            nameByID[kp.id] = (kp.name, kp.subject, kp.grade)
        }
        for kp in ContentCatalog.knowledgePoints where nameByID[kp.id] == nil {
            nameByID[kp.id] = (kp.name, kp.subject, kp.grade)
        }

        // 1) Real mastery records → weak points (StudyPlanner orders by score).
        let weakPoints = masteries.map {
            WeakPoint(id: $0.knowledgePointID, name: nameByID[$0.knowledgePointID]?.name ?? "知识点",
                      subject: $0.subject, score: $0.score)
        }
        let ranked = StudyPlanner.weakest(weakPoints, limit: 12)
        var built: [DrillTarget] = ranked.map { wp in
            let meta = nameByID[wp.id]
            return DrillTarget(id: wp.id, name: meta?.name ?? wp.name,
                               subject: wp.subject, score: wp.score,
                               grade: meta?.grade ?? profileGrade)
        }

        // 2) Back-fill catalog knowledge points the learner hasn't practiced yet so the
        //    subject/KP picker always offers real choices (treated as "new", score 0).
        let coveredIDs = Set(built.map(\.id))
        let relevantSubjects = profileSubjects.isEmpty ? Subject.allCases : profileSubjects
        let catalogFill = ContentCatalog.knowledgePoints
            .filter { !coveredIDs.contains($0.id) && relevantSubjects.contains($0.subject) }
            .map { DrillTarget(id: $0.id, name: $0.name, subject: $0.subject,
                               score: 0, grade: $0.grade) }
        built.append(contentsOf: catalogFill)

        // A deep-link target (Home weak point, a mistake, a report, a KP screen) that
        // isn't already covered — synthesize it from the name lookup so the drill can
        // focus on it even if it's outside the learner's usual subjects.
        if let preselected, !preselected.isEmpty,
           !built.contains(where: { $0.id == preselected }),
           let meta = nameByID[preselected] {
            let existingScore = masteries.first { $0.knowledgePointID == preselected }?.score ?? 0
            built.insert(
                DrillTarget(id: preselected, name: meta.name, subject: meta.subject,
                            score: existingScore, grade: meta.grade),
                at: 0
            )
        }

        targets = built
        // Honor an explicit deep-link target the first time we see it; otherwise
        // auto-select the weakest when nothing is chosen (or the prior choice vanished).
        let currentIsValid = selectedTarget.map { sel in built.contains { $0.id == sel.id } } ?? false
        if let preselected, !preselected.isEmpty, !currentIsValid,
           let target = built.first(where: { $0.id == preselected }) {
            selectedTarget = target
        } else if !currentIsValid {
            selectedTarget = built.first
        }
    }

    /// Targets grouped by subject for the picker, subjects ordered by display name.
    var targetsBySubject: [(subject: Subject, items: [DrillTarget])] {
        let grouped = Dictionary(grouping: targets, by: \.subject)
        return grouped
            .map { (subject: $0.key, items: $0.value.sorted { $0.score < $1.score }) }
            .sorted { $0.subject.displayName < $1.subject.displayName }
    }

    // MARK: - Generation

    func generate(using intelligence: any IntelligenceService) async {
        guard let target = selectedTarget else {
            generation = .empty(message: "先选择一个练习的知识点吧～")
            return
        }
        generation = .loading
        do {
            let request = SimilarRequest(
                subject: target.subject,
                knowledgePoints: [target.knowledgeRef],
                referenceText: target.name,
                count: requestedCount,
                grade: target.grade
            )
            let generated = try await intelligence.similarProblems(request)
            if generated.isEmpty {
                generation = .empty(message: "这道知识点暂时没有生成题目，换一个试试。")
            } else {
                problems = generated
                resetRunner()
                generation = .loaded(generated)
                phase = .running
                HapticEngine.play(.light)
            }
        } catch {
            generation = .error(message: "出题失败了，请稍后再试。")
        }
    }

    private func resetRunner() {
        currentIndex = 0
        typedAnswer = ""
        hasChecked = false
        outcomes = []
        questionStartedAt = .now
    }

    // MARK: - Runner actions

    /// Lock in the typed answer for the current problem, record the outcome, reveal steps.
    func check() {
        guard !hasChecked, let problem = currentProblem else { return }
        let correct = DrillAnswerChecker.isCorrect(typedAnswer, expected: problem.answer)
        let outcome = DrillOutcome(
            problemID: problem.id,
            question: problem.question,
            typedAnswer: typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
            correctAnswer: problem.answer,
            isCorrect: correct,
            knowledgePointID: problem.knowledgePointID.isEmpty
                ? (selectedTarget?.id ?? "") : problem.knowledgePointID,
            timeSpent: Date.now.timeIntervalSince(questionStartedAt)
        )
        // Replace if re-checking (shouldn't happen — guarded — but keep array aligned).
        if outcomes.indices.contains(currentIndex) {
            outcomes[currentIndex] = outcome
        } else {
            outcomes.append(outcome)
        }
        hasChecked = true
        HapticEngine.play(correct ? .success : .warning)
    }

    /// Advance to the next problem, or move to the finished phase after the last one.
    func advance() {
        guard hasChecked else { return }
        if isLastProblem {
            phase = .finished
            HapticEngine.play(allCorrect ? .success : .light)
        } else {
            currentIndex += 1
            typedAnswer = ""
            hasChecked = false
            questionStartedAt = .now
        }
    }

    // MARK: - Persistence + mastery update

    /// On finish: update (or create) the target `MasteryRecord` from this run's accuracy,
    /// then insert a `PracticeSession` + one `PracticeAttempt` per problem. Idempotent —
    /// only writes once per finished session.
    private(set) var saved = false

    func persistResults(context: ModelContext, existingMasteries: [MasteryRecord]) {
        guard !saved, !outcomes.isEmpty, let target = selectedTarget else { return }

        // 1) Mastery: blend the prior score with this run's accuracy (gentle EMA) so a
        //    good session lifts a weak point without overshooting, and a bad one nudges
        //    it down. Then bump attempt/correct counts.
        let record: MasteryRecord
        if let existing = existingMasteries.first(where: { $0.knowledgePointID == target.id }) {
            record = existing
        } else {
            let fresh = MasteryRecord()
            fresh.knowledgePointID = target.id
            fresh.subject = target.subject
            fresh.score = target.score
            context.insert(fresh)
            record = fresh
        }
        let blended = record.score * 0.6 + accuracy * 0.4
        record.score = min(1, max(0, blended))
        record.attempts += outcomes.count
        record.correctCount += correctCount
        // A perfect run counts as a clean explanation streak; any miss resets it.
        record.consecutiveExplains = allCorrect ? record.consecutiveExplains + 1 : 0
        record.lastUpdated = .now

        // 2) Session + attempts.
        let session = PracticeSession()
        session.subject = target.subject
        session.title = "靶向练习 · \(target.name)"
        session.kindRaw = "targeted"
        session.targetKnowledgePointIDs = [target.id]
        session.totalCount = outcomes.count
        session.correctCount = correctCount
        session.estMinutes = estimatedMinutes
        session.completed = true
        session.completedAt = .now
        context.insert(session)

        for outcome in outcomes {
            let attempt = PracticeAttempt()
            attempt.questionText = outcome.question
            attempt.answer = outcome.typedAnswer
            attempt.correctAnswer = outcome.correctAnswer
            attempt.isCorrect = outcome.isCorrect
            attempt.knowledgePointID = outcome.knowledgePointID
            attempt.timeSpent = outcome.timeSpent
            attempt.session = session
            context.insert(attempt)
        }

        try? context.save()
        saved = true
    }

    /// Start a fresh session on the same target (再练一组) — back to generation.
    func restart() {
        phase = .setup
        generation = .idle
        problems = []
        saved = false
        resetRunner()
    }
}

// MARK: - Per-problem outcome (pure)

/// What the learner did on one problem. Captured at check time so results + the
/// persisted `PracticeAttempt`s read from one immutable source.
nonisolated struct DrillOutcome: Identifiable, Hashable, Sendable {
    let problemID: String
    let question: String
    let typedAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
    let knowledgePointID: String
    let timeSpent: TimeInterval

    var id: String { problemID }
}
