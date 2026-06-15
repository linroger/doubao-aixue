//
//  IntelligenceService.swift
//  豆包爱学
//
//  The single AI abstraction. Every feature depends only on this protocol, so
//  the app is provider-agnostic, offline-capable, and testable. A fully
//  functional MockIntelligenceService is the default; FoundationModelsService
//  layers on top when Apple Intelligence is available.
//

import SwiftUI

public nonisolated protocol IntelligenceService: Sendable {
    var capabilities: IntelligenceCapabilities { get }

    func solve(_ request: SolveRequest) async throws -> SolvedProblem
    func gradeEssay(_ request: EssayGradeRequest) async throws -> EssayFeedback
    func gradeArithmetic(_ request: ArithmeticGradeRequest) async throws -> GradedArithmetic
    func similarProblems(_ request: SimilarRequest) async throws -> [GeneratedProblem]
    func explainKnowledgePoint(_ request: ExplainRequest) async throws -> KnowledgeExplanation
    func summarizeDocument(_ request: DocSummarizeRequest) async throws -> DocumentSummary
    func answerAboutDocument(_ request: DocQARequest) async throws -> DocAnswer
    func generateLesson(_ request: LessonRequest) async throws -> GeneratedLesson
    func gradeDictation(_ request: DictationGradeRequest) async throws -> DictationGrading
    func scorePronunciation(_ request: PronunciationRequest) async throws -> PronunciationScore

    /// Streamed tutor session (动态板书 + 讲解) — one segment at a time.
    func tutorSession(_ request: TutorRequest) -> AsyncThrowingStream<TutorEvent, Error>
    /// Streamed chat reply (token-ish deltas, final chunk carries rich blocks).
    func chat(_ request: ChatRequest) -> AsyncThrowingStream<ChatChunk, Error>
}

// MARK: - Environment injection

private struct IntelligenceServiceKey: EnvironmentKey {
    static let defaultValue: any IntelligenceService = MockIntelligenceService()
}

public extension EnvironmentValues {
    var intelligence: any IntelligenceService {
        get { self[IntelligenceServiceKey.self] }
        set { self[IntelligenceServiceKey.self] = newValue }
    }
}
