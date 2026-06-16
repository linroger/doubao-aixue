//
//  WorkbookGradingTypes.swift
//  豆包爱学
//
//  The structured-output schema for 作业批改 (workbook grading): upload a photo of a
//  workbook page and the AI returns a `GradedWorkbook` — a rich, subject-agnostic,
//  render-ready result. Designed to describe ANY workbook question (math / 语文 /
//  English / 物理 / 化学 / 综合 …) with enough structure for a beautiful SwiftUI
//  layout, while degrading gracefully when fields are absent.
//
//  Pure Codable/Sendable value types: they flow through the Intelligence DTO layer
//  (provider replies parsed into these), are rendered directly by the result view,
//  and are persisted by `WorkbookGradeRecord` as encoded JSON (搜题历史 for grading).
//

import Foundation

// MARK: - Verdict

/// The judgement for one graded question. Subject-agnostic — a 选择题, a 计算题, and a
/// 作文 all map onto the same small set, so the UI can render a single consistent
/// badge while the explanation carries the nuance.
public nonisolated enum GradeVerdict: String, Codable, Sendable, Hashable, CaseIterable {
    case correct        // ✓ 正确
    case incorrect      // ✗ 错误
    case partial        // ◐ 部分正确 (e.g. multi-part answer, essay below full marks)
    case unattempted    // ○ 未作答 / 空白
    case ungradable     // ? 无法判定 (recognition unclear, or open-ended without a key)

    public var displayName: String {
        switch self {
        case .correct: "正确"
        case .incorrect: "错误"
        case .partial: "部分正确"
        case .unattempted: "未作答"
        case .ungradable: "待确认"
        }
    }

    public var symbolName: String {
        switch self {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .unattempted: "circle.dashed"
        case .ungradable: "questionmark.circle.fill"
        }
    }

    /// Lenient parse from a model reply ("对"/"true"/"right"/"✓" → .correct, …).
    public static func parse(_ raw: String?) -> GradeVerdict {
        guard let raw else { return .ungradable }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = GradeVerdict(rawValue: s) { return exact }
        switch s {
        case "对", "正确", "right", "true", "yes", "✓", "√", "1": return .correct
        case "错", "错误", "wrong", "false", "no", "✗", "×", "x", "0": return .incorrect
        case "部分", "部分正确", "partial", "half", "◐": return .partial
        case "空", "空白", "未作答", "blank", "empty", "skipped", "○": return .unattempted
        default: return .ungradable
        }
    }
}

// MARK: - Question type

/// A broad question-type taxonomy spanning every subject. Drives the small type chip
/// and lets the renderer pick the right layout (e.g. show choices, show a rubric for
/// essays). New subjects fold into `.other` rather than breaking the schema.
public nonisolated enum WorkbookQuestionType: String, Codable, Sendable, Hashable, CaseIterable {
    case calculation     // 计算题
    case fillInBlank     // 填空题
    case multipleChoice  // 选择题
    case trueFalse       // 判断题
    case shortAnswer     // 简答题
    case application     // 应用题 / 解答题
    case proof           // 证明题
    case essay           // 作文 / 写作
    case translation     // 翻译
    case reading         // 阅读理解
    case dictation       // 默写 / 听写
    case matching        // 连线 / 匹配
    case handwriting     // 书写 / 看拼音写词
    case other

    public var displayName: String {
        switch self {
        case .calculation: "计算"
        case .fillInBlank: "填空"
        case .multipleChoice: "选择"
        case .trueFalse: "判断"
        case .shortAnswer: "简答"
        case .application: "应用题"
        case .proof: "证明"
        case .essay: "作文"
        case .translation: "翻译"
        case .reading: "阅读"
        case .dictation: "默写"
        case .matching: "连线"
        case .handwriting: "书写"
        case .other: "题目"
        }
    }

    public var symbolName: String {
        switch self {
        case .calculation: "plus.forwardslash.minus"
        case .fillInBlank: "square.dashed"
        case .multipleChoice: "list.bullet.circle"
        case .trueFalse: "checkmark.circle"
        case .shortAnswer: "text.alignleft"
        case .application: "function"
        case .proof: "arrow.triangle.branch"
        case .essay: "text.book.closed.fill"
        case .translation: "character.bubble"
        case .reading: "book.pages"
        case .dictation: "ear"
        case .matching: "arrow.left.and.right"
        case .handwriting: "pencil.and.scribble"
        case .other: "doc.text"
        }
    }

    /// Subjective types are scored against a rubric and never marked plain "错".
    public var isSubjective: Bool {
        switch self {
        case .essay, .shortAnswer, .translation, .reading, .proof: true
        default: false
        }
    }

    /// Lenient parse from a free-form model label.
    public static func parse(_ raw: String?) -> WorkbookQuestionType {
        guard let raw else { return .other }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = WorkbookQuestionType(rawValue: s) { return exact }
        let map: [(keys: [String], type: WorkbookQuestionType)] = [
            (["计算", "口算", "运算", "compute", "calc"], .calculation),
            (["填空", "fill", "blank"], .fillInBlank),
            (["选择", "单选", "多选", "choice", "mcq", "select"], .multipleChoice),
            (["判断", "对错", "true", "false", "判断题"], .trueFalse),
            (["简答", "问答", "short"], .shortAnswer),
            (["应用", "解答", "word problem", "application"], .application),
            (["证明", "proof"], .proof),
            (["作文", "写作", "essay", "composition", "writing"], .essay),
            (["翻译", "translate", "translation"], .translation),
            (["阅读", "理解", "reading", "comprehension"], .reading),
            (["默写", "听写", "dictation"], .dictation),
            (["连线", "匹配", "match"], .matching),
            (["书写", "拼音", "handwrit", "字"], .handwriting),
        ]
        for entry in map where entry.keys.contains(where: { s.contains($0) }) {
            return entry.type
        }
        return .other
    }
}

// MARK: - Graded question

/// One graded question on the page. Rich enough for any subject; the renderer shows
/// only the fields that are present, so a bare 口算 item and a fully-rubric'd 作文 both
/// look intentional.
public nonisolated struct GradedQuestion: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    /// Human label as printed on the page ("1", "2(a)", "三、5", "Q3").
    public var number: String
    public var type: WorkbookQuestionType
    public var subject: Subject
    /// The recognized question prompt (may contain LaTeX-ish math, 中文, or English).
    public var questionText: String
    /// What the student wrote, as recognized from the photo.
    public var studentAnswer: String
    /// The correct answer / model answer.
    public var correctAnswer: String
    public var verdict: GradeVerdict
    /// Why it's right/wrong and how to fix it — the core teaching moment.
    public var explanation: String
    /// Mistake taxonomy (for incorrect / partial).
    public var errorType: ErrorType?
    /// Knowledge points this question exercises (tappable chips → 知识点讲解 / 练习).
    public var knowledgePoints: [KnowledgeRef]
    /// Optional scoring (nil when the page isn't point-weighted).
    public var pointsEarned: Double?
    public var pointsPossible: Double?
    /// Optional worked steps (math / proof / application).
    public var steps: [SolutionStep]
    /// Optional rubric breakdown (essays / subjective).
    public var rubric: [RubricDimension]
    /// Optional warm, concise teacher note (praise + one concrete next step).
    public var teacherComment: String?

    public init(id: String = UUID().uuidString,
                number: String,
                type: WorkbookQuestionType,
                subject: Subject,
                questionText: String,
                studentAnswer: String = "",
                correctAnswer: String = "",
                verdict: GradeVerdict,
                explanation: String = "",
                errorType: ErrorType? = nil,
                knowledgePoints: [KnowledgeRef] = [],
                pointsEarned: Double? = nil,
                pointsPossible: Double? = nil,
                steps: [SolutionStep] = [],
                rubric: [RubricDimension] = [],
                teacherComment: String? = nil) {
        self.id = id
        self.number = number
        self.type = type
        self.subject = subject
        self.questionText = questionText
        self.studentAnswer = studentAnswer
        self.correctAnswer = correctAnswer
        self.verdict = verdict
        self.explanation = explanation
        self.errorType = errorType
        self.knowledgePoints = knowledgePoints
        self.pointsEarned = pointsEarned
        self.pointsPossible = pointsPossible
        self.steps = steps
        self.rubric = rubric
        self.teacherComment = teacherComment
    }

    /// A question worth re-practicing (wrong / partial / skipped).
    public var isWrong: Bool {
        switch verdict {
        case .incorrect, .partial, .unattempted: true
        case .correct, .ungradable: false
        }
    }

    /// Render math layout for STEM-ish content.
    public var isMathy: Bool {
        subject.isSTEM || type == .calculation || type == .application || type == .proof
    }
}

// MARK: - Graded workbook

/// The full grading result for one captured page. The model returns this; the app
/// renders and persists it verbatim.
public nonisolated struct GradedWorkbook: Codable, Sendable, Hashable {
    /// A short inferred title, e.g. "数学作业 · 两位数加减法".
    public var title: String
    public var grade: GradeLevel
    /// Subjects detected on the page (usually one; supports mixed pages).
    public var detectedSubjects: [Subject]
    public var questions: [GradedQuestion]
    /// Warm overall summary: what went well + the single most useful next step.
    public var overallComment: String
    /// One short encouraging line spoken by the mascot.
    public var encouragement: String
    public var route: IntelligenceRoute

    public init(title: String,
                grade: GradeLevel = .g5,
                detectedSubjects: [Subject] = [],
                questions: [GradedQuestion],
                overallComment: String = "",
                encouragement: String = "",
                route: IntelligenceRoute = .mock) {
        self.title = title
        self.grade = grade
        self.detectedSubjects = detectedSubjects
        self.questions = questions
        self.overallComment = overallComment
        self.encouragement = encouragement
        self.route = route
    }

    // MARK: Derived metrics (for the summary header)

    public var total: Int { questions.count }
    public var correctCount: Int { questions.filter { $0.verdict == .correct }.count }
    public var incorrectCount: Int { questions.filter { $0.verdict == .incorrect }.count }
    public var partialCount: Int { questions.filter { $0.verdict == .partial }.count }
    public var unattemptedCount: Int { questions.filter { $0.verdict == .unattempted }.count }
    public var ungradableCount: Int { questions.filter { $0.verdict == .ungradable }.count }

    /// Questions worth reviewing (wrong / partial / skipped).
    public var wrongQuestions: [GradedQuestion] { questions.filter(\.isWrong) }

    /// Accuracy over the questions that could be judged objectively.
    public var accuracy: Double {
        let judged = questions.filter { $0.verdict == .correct || $0.verdict == .incorrect || $0.verdict == .partial }
        guard !judged.isEmpty else { return 0 }
        let credit = judged.reduce(0.0) { acc, q in
            switch q.verdict {
            case .correct: acc + 1
            case .partial: acc + 0.5
            default: acc
            }
        }
        return credit / Double(judged.count)
    }

    /// True when the page carries explicit point weights.
    public var isScored: Bool {
        questions.contains { $0.pointsPossible != nil }
    }

    public var scoreEarned: Double {
        questions.reduce(0.0) { $0 + ($1.pointsEarned ?? 0) }
    }

    public var scorePossible: Double {
        questions.reduce(0.0) { $0 + ($1.pointsPossible ?? 0) }
    }

    /// The dominant subject (most common), for chips/persistence.
    public var primarySubject: Subject {
        detectedSubjects.first
            ?? questions.first?.subject
            ?? .general
    }
}
