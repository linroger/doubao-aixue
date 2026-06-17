//
//  QuestionBankModel.swift
//  豆包爱学 — Features/QuestionBank
//
//  The @Observable view model behind 题库 (the review databank). It owns the
//  multi-select state and the AI practice-generation flow: from a set of banked
//  questions it asks `intelligence.similarProblems(_:)` (grouped by subject, seeded
//  with the questions' text + knowledge points) and surfaces fresh practice problems
//  the learner can attempt, reveal, and re-bank.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class QuestionBankModel {
    // Multi-select.
    var selecting = false
    var selectedIDs: Set<UUID> = []

    // Practice generation.
    var showPractice = false
    var practiceState: ViewState<[GeneratedProblem]> = .idle
    var revealedIDs: Set<String> = []
    var bankedGeneratedIDs: Set<String> = []
    private(set) var lastSeedSubjects: [Subject] = []

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func clearSelection() {
        selecting = false
        selectedIDs.removeAll()
    }

    /// Generate fresh practice from seed questions. If a selection exists it's used;
    /// otherwise the caller passes the current filtered list (capped upstream).
    func generatePractice(seeds: [BankedQuestion], grade: GradeLevel,
                          using intelligence: any IntelligenceService) async {
        let capped = Array(seeds.prefix(12))
        guard !capped.isEmpty else {
            practiceState = .empty(message: "题库还没有题目可以参考。先收藏一些题目，再来智能出题吧。")
            showPractice = true
            return
        }
        showPractice = true
        practiceState = .loading
        revealedIDs.removeAll()
        bankedGeneratedIDs.removeAll()

        let bySubject = Dictionary(grouping: capped, by: \.subject)
        lastSeedSubjects = bySubject.keys.sorted { $0.displayName < $1.displayName }
        let perSubject = max(2, min(5, 8 / max(1, bySubject.count)))

        var generated: [GeneratedProblem] = []
        for subject in lastSeedSubjects {
            let qs = bySubject[subject] ?? []
            // Dedupe knowledge points by id, keep a handful.
            var seenKP = Set<String>()
            let kps = qs.flatMap(\.knowledgePoints).filter { seenKP.insert($0.id).inserted }
            let reference = qs.prefix(4).map(\.questionText).joined(separator: "\n")
            let request = SimilarRequest(
                subject: subject, knowledgePoints: Array(kps.prefix(4)),
                referenceText: reference, count: perSubject, grade: grade)
            if let problems = try? await intelligence.similarProblems(request) {
                generated.append(contentsOf: problems)
            }
        }

        practiceState = generated.isEmpty
            ? .empty(message: "这次没有生成新题，换几道题再试试吧。")
            : .loaded(generated)
        if !generated.isEmpty { HapticEngine.play(.success) }
    }

    func reveal(_ id: String) {
        revealedIDs.insert(id)
        HapticEngine.play(.light)
    }

    /// Save a generated problem back into the bank (source .generated).
    func bankGenerated(_ problem: GeneratedProblem, subject: Subject, context: ModelContext) {
        guard !bankedGeneratedIDs.contains(problem.id) else { return }
        let item = BankedQuestion()
        item.subject = subject
        item.type = .other
        item.questionText = problem.question
        item.correctAnswer = problem.answer
        item.steps = problem.steps
        // Carry the explanation + knowledge point so the re-banked question is as
        // reviewable as its source and seeds future 智能出题 just as well.
        item.explanation = problem.steps.first?.detail ?? ""
        if !problem.knowledgePointID.isEmpty {
            let name = ContentCatalog.knowledgePoints.first { $0.id == problem.knowledgePointID }?.name
                ?? problem.knowledgePointID
            item.knowledgePointIDs = [problem.knowledgePointID]
            item.knowledgePointNames = [name]
        }
        item.source = .generated
        item.mastery = .new
        item.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        context.insert(item)
        if context.saveLogging() {
            bankedGeneratedIDs.insert(problem.id)
            HapticEngine.play(.success)
        }
    }
}
