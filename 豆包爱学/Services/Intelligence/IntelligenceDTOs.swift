//
//  IntelligenceDTOs.swift
//  豆包爱学
//
//  Pure, Sendable request/response value types for the Intelligence layer.
//  Compose the shared value types (SolutionStep, RubricDimension, …).
//  All nonisolated so providers (actors / nonisolated services) can use them.
//

import Foundation

// MARK: - Context & capability

public nonisolated struct LearnerContext: Sendable, Hashable {
    public var grade: GradeLevel
    public var subjects: [Subject]
    public var weakKnowledgePointIDs: [String]
    public var learnModeEnabled: Bool
    public init(grade: GradeLevel = .g5, subjects: [Subject] = [],
                weakKnowledgePointIDs: [String] = [], learnModeEnabled: Bool = true) {
        self.grade = grade; self.subjects = subjects
        self.weakKnowledgePointIDs = weakKnowledgePointIDs; self.learnModeEnabled = learnModeEnabled
    }
    public static let preview = LearnerContext(grade: .g5, subjects: [.math, .chinese, .english])
}

public nonisolated struct IntelligenceCapabilities: Sendable, Hashable {
    public var route: IntelligenceRoute
    public var modelName: String
    public var supportsStreaming: Bool
    public init(route: IntelligenceRoute, modelName: String, supportsStreaming: Bool) {
        self.route = route; self.modelName = modelName; self.supportsStreaming = supportsStreaming
    }
}

// MARK: - Solve

public nonisolated struct SolveRequest: Sendable, Hashable {
    public var recognizedText: String
    public var subject: Subject?
    public var grade: GradeLevel
    public var mode: CaptureMode
    public var learnMode: Bool
    /// The original capture, when available. A vision-capable cloud model reads it
    /// directly (handwriting / geometry / diagrams), with `recognizedText` as the hint
    /// and the text-only path as a fallback.
    public var imageData: Data?
    public init(recognizedText: String, subject: Subject? = nil, grade: GradeLevel = .g5,
                mode: CaptureMode = .solve, learnMode: Bool = true, imageData: Data? = nil) {
        self.recognizedText = recognizedText; self.subject = subject
        self.grade = grade; self.mode = mode; self.learnMode = learnMode
        self.imageData = imageData
    }
}

public nonisolated struct SolvedProblem: Sendable, Hashable {
    public var subject: Subject
    public var approach: String                 // 思路
    public var steps: [SolutionStep]
    public var finalAnswer: String
    public var choices: [ChoiceOption]          // for MCQ; empty otherwise
    public var knowledgePoints: [KnowledgeRef]
    public var route: IntelligenceRoute
    public init(subject: Subject, approach: String, steps: [SolutionStep], finalAnswer: String,
                choices: [ChoiceOption] = [], knowledgePoints: [KnowledgeRef] = [],
                route: IntelligenceRoute = .mock) {
        self.subject = subject; self.approach = approach; self.steps = steps
        self.finalAnswer = finalAnswer; self.choices = choices
        self.knowledgePoints = knowledgePoints; self.route = route
    }
}

// MARK: - Workbook grading (作业批改)

/// Request to grade a photographed workbook page. Carries the raw image (sent to a
/// vision-capable model) plus a best-effort on-device OCR pre-pass (`recognizedText`)
/// so providers without image input — or any failure path — can still grade from text.
public nonisolated struct WorkbookGradeRequest: Sendable, Hashable {
    public var imageData: Data
    public var recognizedText: String        // OCR pre-pass: hint for vision, fallback for text-only
    public var subjectHint: Subject?         // user-selected subject, or nil for auto-detect
    public var grade: GradeLevel
    public var learnMode: Bool
    public init(imageData: Data, recognizedText: String = "", subjectHint: Subject? = nil,
                grade: GradeLevel = .g5, learnMode: Bool = true) {
        self.imageData = imageData
        self.recognizedText = recognizedText
        self.subjectHint = subjectHint
        self.grade = grade
        self.learnMode = learnMode
    }
}

// MARK: - Essay grading

public nonisolated struct EssayGradeRequest: Sendable, Hashable {
    public var text: String
    public var subject: Subject
    public var examType: String
    public var grade: GradeLevel
    public var prompt: String
    public init(text: String, subject: Subject = .chinese, examType: String = "",
                grade: GradeLevel = .g9, prompt: String = "") {
        self.text = text; self.subject = subject; self.examType = examType
        self.grade = grade; self.prompt = prompt
    }
}

public nonisolated struct EssayFeedback: Sendable, Hashable {
    public var overallComment: String
    public var score: Double
    public var maxScore: Double
    public var rubric: [RubricDimension]
    public var annotations: [SentenceAnnotation]
    public var polishedText: String             // 升格作文
    public var highScoreExpressions: [String]
    public var strengths: [String]
    public var route: IntelligenceRoute
    public init(overallComment: String, score: Double, maxScore: Double, rubric: [RubricDimension],
                annotations: [SentenceAnnotation], polishedText: String,
                highScoreExpressions: [String] = [], strengths: [String] = [], route: IntelligenceRoute = .mock) {
        self.overallComment = overallComment; self.score = score; self.maxScore = maxScore
        self.rubric = rubric; self.annotations = annotations; self.polishedText = polishedText
        self.highScoreExpressions = highScoreExpressions; self.strengths = strengths; self.route = route
    }
}

// MARK: - Arithmetic grading

public nonisolated struct ArithmeticItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var expression: String
    public var studentAnswer: String
    public init(id: String = UUID().uuidString, expression: String, studentAnswer: String) {
        self.id = id; self.expression = expression; self.studentAnswer = studentAnswer
    }
}

public nonisolated struct ArithmeticGradeRequest: Sendable, Hashable {
    public var items: [ArithmeticItem]
    public var grade: GradeLevel
    public init(items: [ArithmeticItem], grade: GradeLevel = .g3) {
        self.items = items; self.grade = grade
    }
}

public nonisolated struct GradedArithmeticItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var expression: String
    public var studentAnswer: String
    public var correctAnswer: String
    public var isCorrect: Bool
    public var errorType: ErrorType?
    public var explanation: String
    public init(id: String = UUID().uuidString, expression: String, studentAnswer: String,
                correctAnswer: String, isCorrect: Bool, errorType: ErrorType? = nil, explanation: String = "") {
        self.id = id; self.expression = expression; self.studentAnswer = studentAnswer
        self.correctAnswer = correctAnswer; self.isCorrect = isCorrect
        self.errorType = errorType; self.explanation = explanation
    }
}

public nonisolated struct GradedArithmetic: Sendable, Hashable {
    public var items: [GradedArithmeticItem]
    public var route: IntelligenceRoute
    public init(items: [GradedArithmeticItem], route: IntelligenceRoute = .mock) {
        self.items = items; self.route = route
    }
    public var correctCount: Int { items.filter(\.isCorrect).count }
    public var total: Int { items.count }
}

// MARK: - Similar / generated problems

public nonisolated struct SimilarRequest: Sendable, Hashable {
    public var subject: Subject
    public var knowledgePoints: [KnowledgeRef]
    public var referenceText: String
    public var count: Int
    public var grade: GradeLevel
    public init(subject: Subject, knowledgePoints: [KnowledgeRef] = [], referenceText: String = "",
                count: Int = 3, grade: GradeLevel = .g5) {
        self.subject = subject; self.knowledgePoints = knowledgePoints
        self.referenceText = referenceText; self.count = count; self.grade = grade
    }
}

public nonisolated struct GeneratedProblem: Sendable, Hashable, Identifiable {
    public var id: String
    public var question: String
    public var answer: String
    public var steps: [SolutionStep]
    public var difficulty: Int                  // 1...5
    public var knowledgePointID: String
    public init(id: String = UUID().uuidString, question: String, answer: String,
                steps: [SolutionStep] = [], difficulty: Int = 2, knowledgePointID: String = "") {
        self.id = id; self.question = question; self.answer = answer
        self.steps = steps; self.difficulty = difficulty; self.knowledgePointID = knowledgePointID
    }
}

// MARK: - Tutor (豆包老师)

public nonisolated struct TutorRequest: Sendable, Hashable {
    public var problemText: String
    public var subject: Subject
    public var grade: GradeLevel
    public var learnMode: Bool
    public init(problemText: String, subject: Subject = .math, grade: GradeLevel = .g5, learnMode: Bool = true) {
        self.problemText = problemText; self.subject = subject; self.grade = grade; self.learnMode = learnMode
    }
}

public nonisolated enum TutorEvent: Sendable {
    case segment(TutorSegment)
    case done
}

// MARK: - Chat

public nonisolated struct ChatTurn: Sendable, Hashable {
    public var role: ChatRole
    public var text: String
    public init(role: ChatRole, text: String) { self.role = role; self.text = text }
}

public nonisolated enum ConversationKind: String, Sendable { case tutor, companion, knowledge }

public nonisolated struct ChatRequest: Sendable, Hashable {
    public var turns: [ChatTurn]
    public var context: LearnerContext
    public var kind: ConversationKind
    public init(turns: [ChatTurn], context: LearnerContext = .preview, kind: ConversationKind = .knowledge) {
        self.turns = turns; self.context = context; self.kind = kind
    }
}

public nonisolated struct ChatChunk: Sendable {
    public var delta: String
    public var isFinal: Bool
    public var blocks: [RichBlock]
    public var route: IntelligenceRoute
    public init(delta: String, isFinal: Bool = false, blocks: [RichBlock] = [], route: IntelligenceRoute = .mock) {
        self.delta = delta; self.isFinal = isFinal; self.blocks = blocks; self.route = route
    }
}

// MARK: - Knowledge explanation

public nonisolated struct ExplainRequest: Sendable, Hashable {
    public var knowledgePoint: String
    public var subject: Subject
    public var grade: GradeLevel
    public init(knowledgePoint: String, subject: Subject = .math, grade: GradeLevel = .g5) {
        self.knowledgePoint = knowledgePoint; self.subject = subject; self.grade = grade
    }
}

public nonisolated struct ExplanationSection: Sendable, Hashable, Identifiable {
    public var id: String
    public var heading: String                  // 背景 / 内容 / 价值
    public var body: String
    public var math: String?
    public init(id: String = UUID().uuidString, heading: String, body: String, math: String? = nil) {
        self.id = id; self.heading = heading; self.body = body; self.math = math
    }
}

public nonisolated struct KnowledgeExplanation: Sendable, Hashable {
    public var title: String
    public var sections: [ExplanationSection]
    public var board: [BoardElement]
    public var extensionQuestions: [String]
    public var route: IntelligenceRoute
    public init(title: String, sections: [ExplanationSection], board: [BoardElement] = [],
                extensionQuestions: [String] = [], route: IntelligenceRoute = .mock) {
        self.title = title; self.sections = sections; self.board = board
        self.extensionQuestions = extensionQuestions; self.route = route
    }
}

// MARK: - Document Q&A

public nonisolated struct DocSummarizeRequest: Sendable, Hashable {
    public var title: String
    public var text: String
    public init(title: String, text: String) { self.title = title; self.text = text }
}

public nonisolated struct DocumentSummary: Sendable, Hashable {
    public var summary: String
    public var keyPoints: [String]
    public var outline: [String]
    public var route: IntelligenceRoute
    public init(summary: String, keyPoints: [String], outline: [String], route: IntelligenceRoute = .mock) {
        self.summary = summary; self.keyPoints = keyPoints; self.outline = outline; self.route = route
    }
}

public nonisolated struct DocQARequest: Sendable, Hashable {
    public var documentText: String
    public var question: String
    public init(documentText: String, question: String) {
        self.documentText = documentText; self.question = question
    }
}

public nonisolated struct DocAnswer: Sendable, Hashable {
    public var answer: String
    public var citedSpans: [String]
    public var route: IntelligenceRoute
    public init(answer: String, citedSpans: [String] = [], route: IntelligenceRoute = .mock) {
        self.answer = answer; self.citedSpans = citedSpans; self.route = route
    }
}

// MARK: - Lesson generation

public nonisolated struct LessonRequest: Sendable, Hashable {
    public var topic: String
    public var subject: Subject
    public var grade: GradeLevel
    public init(topic: String, subject: Subject = .chinese, grade: GradeLevel = .g6) {
        self.topic = topic; self.subject = subject; self.grade = grade
    }
}

public nonisolated struct GeneratedLesson: Sendable, Hashable {
    public var title: String
    public var segments: [TutorSegment]
    public var knowledgePoints: [KnowledgeRef]
    public var route: IntelligenceRoute
    public init(title: String, segments: [TutorSegment], knowledgePoints: [KnowledgeRef] = [], route: IntelligenceRoute = .mock) {
        self.title = title; self.segments = segments; self.knowledgePoints = knowledgePoints; self.route = route
    }
}

// MARK: - Dictation grading

public nonisolated struct DictationGradeRequest: Sendable, Hashable {
    public var expected: [String]
    public var written: [String]
    public init(expected: [String], written: [String]) { self.expected = expected; self.written = written }
}

public nonisolated struct DictationWordResult: Sendable, Hashable, Identifiable {
    public var id: String
    public var expected: String
    public var written: String
    public var isCorrect: Bool
    public init(id: String = UUID().uuidString, expected: String, written: String, isCorrect: Bool) {
        self.id = id; self.expected = expected; self.written = written; self.isCorrect = isCorrect
    }
}

public nonisolated struct DictationGrading: Sendable, Hashable {
    public var results: [DictationWordResult]
    public var route: IntelligenceRoute
    public init(results: [DictationWordResult], route: IntelligenceRoute = .mock) {
        self.results = results; self.route = route
    }
    public var correct: Int { results.filter(\.isCorrect).count }
    public var total: Int { results.count }
}

// MARK: - Pronunciation

public nonisolated struct PronunciationRequest: Sendable, Hashable {
    public var referenceText: String
    public var recognizedText: String
    public init(referenceText: String, recognizedText: String) {
        self.referenceText = referenceText; self.recognizedText = recognizedText
    }
}

public nonisolated struct PronunciationScore: Sendable, Hashable {
    public var overall: Double
    public var accuracy: Double
    public var fluency: Double
    public var completeness: Double
    public var perWord: [WordScore]
    public var route: IntelligenceRoute
    public init(overall: Double, accuracy: Double, fluency: Double, completeness: Double,
                perWord: [WordScore], route: IntelligenceRoute = .mock) {
        self.overall = overall; self.accuracy = accuracy; self.fluency = fluency
        self.completeness = completeness; self.perWord = perWord; self.route = route
    }
}

// MARK: - Errors

public nonisolated enum IntelligenceError: Error, Sendable {
    case unavailable
    case emptyInput
    case generationFailed(String)
}
