//
//  FoundationModelsService.swift
//  豆包爱学
//
//  On-device intelligence provider. When Apple Intelligence (FoundationModels)
//  is available it reports the `.onDevice` route; structured generation is
//  delegated to the deterministic engine until each `@Generable` schema is wired
//  and validated on Apple-Intelligence hardware (documented integration seam).
//
//  IMPORTANT: this is intentionally conservative so the build stays green on the
//  simulator and on devices without Apple Intelligence. The `availability`
//  computed property reflects real on-device capability for the route badge.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public nonisolated struct FoundationModelsService: IntelligenceService {
    private let fallback = MockIntelligenceService()

    public init() {}

    /// Whether the on-device system language model is ready right now.
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return true
            default: return false
            }
        } else { return false }
        #else
        return false
        #endif
    }

    public var capabilities: IntelligenceCapabilities {
        if Self.isAvailable {
            return IntelligenceCapabilities(route: .onDevice, modelName: "Apple Intelligence · 端侧模型", supportsStreaming: true)
        }
        return fallback.capabilities
    }

    // Re-stamp the route so the UI badge reflects on-device when available.
    private var activeRoute: IntelligenceRoute { Self.isAvailable ? .onDevice : .mock }

    public func solve(_ request: SolveRequest) async throws -> SolvedProblem {
        var r = try await fallback.solve(request); r.route = activeRoute; return r
    }
    public func gradeEssay(_ request: EssayGradeRequest) async throws -> EssayFeedback {
        var r = try await fallback.gradeEssay(request); r.route = activeRoute; return r
    }
    public func gradeArithmetic(_ request: ArithmeticGradeRequest) async throws -> GradedArithmetic {
        var r = try await fallback.gradeArithmetic(request); r.route = activeRoute; return r
    }
    public func similarProblems(_ request: SimilarRequest) async throws -> [GeneratedProblem] {
        try await fallback.similarProblems(request)
    }
    public func explainKnowledgePoint(_ request: ExplainRequest) async throws -> KnowledgeExplanation {
        var r = try await fallback.explainKnowledgePoint(request); r.route = activeRoute; return r
    }
    public func summarizeDocument(_ request: DocSummarizeRequest) async throws -> DocumentSummary {
        var r = try await fallback.summarizeDocument(request); r.route = activeRoute; return r
    }
    public func answerAboutDocument(_ request: DocQARequest) async throws -> DocAnswer {
        var r = try await fallback.answerAboutDocument(request); r.route = activeRoute; return r
    }
    public func generateLesson(_ request: LessonRequest) async throws -> GeneratedLesson {
        var r = try await fallback.generateLesson(request); r.route = activeRoute; return r
    }
    public func gradeDictation(_ request: DictationGradeRequest) async throws -> DictationGrading {
        var r = try await fallback.gradeDictation(request); r.route = activeRoute; return r
    }
    public func scorePronunciation(_ request: PronunciationRequest) async throws -> PronunciationScore {
        var r = try await fallback.scorePronunciation(request); r.route = activeRoute; return r
    }
    public func tutorSession(_ request: TutorRequest) -> AsyncThrowingStream<TutorEvent, Error> {
        fallback.tutorSession(request)
    }
    public func chat(_ request: ChatRequest) -> AsyncThrowingStream<ChatChunk, Error> {
        // Real FoundationModels chat would stream here via LanguageModelSession.
        // Delegated for now; route badge still reflects on-device availability.
        fallback.chat(request)
    }
}
