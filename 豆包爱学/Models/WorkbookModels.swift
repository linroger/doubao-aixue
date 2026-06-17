//
//  WorkbookModels.swift
//  豆包爱学
//
//  Persistence for 作业批改 (workbook grading) and 题库 (question bank).
//
//  • `WorkbookGradeRecord` is the grading history: it stores the original page
//    photo, the full structured `GradedWorkbook` result (encoded JSON), and summary
//    metadata so a past grading re-renders pixel-for-pixel from disk.
//  • `BankedQuestion` is the review databank: any question (a wrong one auto-saved
//    from grading/solve, or one the learner saves manually) lands here for later
//    review and AI practice generation.
//
//  Both follow the app's SwiftData conventions: every stored property has a default
//  (CloudKit-compatible), enums persist as raw strings behind computed accessors,
//  and large blobs use external storage.
//

import Foundation
import SwiftData

// MARK: - Workbook grading history

/// One graded workbook page: the photo, the structured result, and summary metadata.
@Model
public final class WorkbookGradeRecord {
    public var id: UUID = UUID()
    public var title: String = "作业批改"
    @Attribute(.externalStorage) public var imageData: Data? = nil
    public var resultData: Data? = nil             // encoded GradedWorkbook
    public var subjectRaw: String = Subject.general.rawValue
    public var gradeRaw: Int = GradeLevel.g5.rawValue
    public var totalCount: Int = 0
    public var correctCount: Int = 0
    public var wrongCount: Int = 0
    public var scoreEarned: Double = 0
    public var scorePossible: Double = 0
    public var routeRaw: String = IntelligenceRoute.mock.rawValue
    public var createdAt: Date = Date()

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .general }
        set { subjectRaw = newValue.rawValue }
    }
    public var grade: GradeLevel {
        get { GradeLevel(rawValue: gradeRaw) ?? .g5 }
        set { gradeRaw = newValue.rawValue }
    }
    public var route: IntelligenceRoute {
        get { IntelligenceRoute(rawValue: routeRaw) ?? .mock }
        set { routeRaw = newValue.rawValue }
    }
    /// The full structured result, decoded on demand for re-rendering history.
    public var result: GradedWorkbook? {
        get { DBJSON.decode(GradedWorkbook.self, from: resultData) }
        set { resultData = newValue.flatMap { DBJSON.encode($0) } }
    }

    /// Build a record from a freshly graded workbook + its source image.
    public static func make(from workbook: GradedWorkbook, imageData: Data?) -> WorkbookGradeRecord {
        let record = WorkbookGradeRecord()
        record.title = workbook.title
        record.imageData = imageData
        record.result = workbook
        record.subject = workbook.primarySubject
        record.grade = workbook.grade
        record.totalCount = workbook.total
        record.correctCount = workbook.correctCount
        record.wrongCount = workbook.wrongQuestions.count
        record.scoreEarned = workbook.scoreEarned
        record.scorePossible = workbook.scorePossible
        record.route = workbook.route
        record.createdAt = Date()
        return record
    }
}

// MARK: - Question bank (题库)

/// Where a banked question came from — drives the source chip and lets the bank
/// explain why a question is here.
public nonisolated enum BankSource: String, Codable, Sendable, CaseIterable {
    case workbook     // 作业批改错题
    case solve        // 拍题解题收藏
    case mistake      // 错题本
    case manual       // 手动添加
    case generated    // AI 生成练习

    public var displayName: String {
        switch self {
        case .workbook: "作业批改"
        case .solve: "拍题解题"
        case .mistake: "错题本"
        case .manual: "手动添加"
        case .generated: "智能出题"
        }
    }

    public var symbolName: String {
        switch self {
        case .workbook: "checklist"
        case .solve: "camera.viewfinder"
        case .mistake: "book.closed.fill"
        case .manual: "square.and.pencil"
        case .generated: "sparkles"
        }
    }
}

/// A question saved to the review databank for later study + AI practice generation.
@Model
public final class BankedQuestion {
    public var id: UUID = UUID()
    public var subjectRaw: String = Subject.general.rawValue
    public var typeRaw: String = WorkbookQuestionType.other.rawValue
    public var questionText: String = ""
    @Attribute(.externalStorage) public var imageData: Data? = nil
    public var studentAnswer: String = ""
    public var correctAnswer: String = ""
    public var explanation: String = ""
    public var errorTypeRaw: String? = nil
    public var knowledgePointIDs: [String] = []
    public var knowledgePointNames: [String] = []
    public var stepsData: Data? = nil              // encoded [SolutionStep]
    public var sourceRaw: String = BankSource.manual.rawValue
    public var tags: [String] = []
    public var starred: Bool = false
    public var masteryRaw: String = MasteryState.new.rawValue
    public var reviewCount: Int = 0
    public var nextReviewAt: Date = Date()
    public var lastReviewedAt: Date? = nil
    public var createdAt: Date = Date()

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .general }
        set { subjectRaw = newValue.rawValue }
    }
    public var type: WorkbookQuestionType {
        get { WorkbookQuestionType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
    public var source: BankSource {
        get { BankSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
    public var errorType: ErrorType? {
        get { errorTypeRaw.flatMap { ErrorType(rawValue: $0) } }
        set { errorTypeRaw = newValue?.rawValue }
    }
    public var mastery: MasteryState {
        get { MasteryState(rawValue: masteryRaw) ?? .new }
        set { masteryRaw = newValue.rawValue }
    }
    public var steps: [SolutionStep] {
        get { DBJSON.decode([SolutionStep].self, from: stepsData) ?? [] }
        set { stepsData = DBJSON.encode(newValue) }
    }

    /// Knowledge-point references reconstructed from the parallel id/name arrays.
    public var knowledgePoints: [KnowledgeRef] {
        zip(knowledgePointIDs, knowledgePointNames).map { id, name in
            KnowledgeRef(id: id, name: name, subject: subject)
        }
    }

    public func setKnowledgePoints(_ refs: [KnowledgeRef]) {
        knowledgePointIDs = refs.map(\.id)
        knowledgePointNames = refs.map(\.name)
    }

    /// Build a banked question from a graded workbook question.
    public static func make(from q: GradedQuestion, source: BankSource, imageData: Data? = nil) -> BankedQuestion {
        let item = BankedQuestion()
        item.subject = q.subject
        item.type = q.type
        item.questionText = q.questionText
        item.studentAnswer = q.studentAnswer
        item.correctAnswer = q.correctAnswer
        item.explanation = q.explanation
        item.errorType = q.errorType
        item.setKnowledgePoints(q.knowledgePoints)
        item.steps = q.steps
        item.source = source
        item.imageData = imageData
        item.mastery = q.verdict == .correct ? .developing : .new
        item.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        item.createdAt = Date()
        return item
    }

    /// Build a banked question from an 错题本 item so mistakes can feed 智能出题.
    /// `knowledgePointNames` should align with `item.knowledgePointIDs`; when it
    /// doesn't, the ids are used as names so the chips still render.
    public static func make(from item: MistakeItem, knowledgePointNames: [String] = []) -> BankedQuestion {
        let q = BankedQuestion()
        q.subject = item.subject
        q.type = .other                     // MistakeItem carries no question-type
        q.questionText = item.questionText
        q.imageData = item.imageData
        q.studentAnswer = item.studentAnswer
        q.correctAnswer = item.correctAnswer
        q.explanation = item.errorReason    // 错因/解释
        q.errorType = item.errorType
        q.steps = item.steps
        q.knowledgePointIDs = item.knowledgePointIDs
        q.knowledgePointNames = knowledgePointNames.count == item.knowledgePointIDs.count
            ? knowledgePointNames : item.knowledgePointIDs
        q.source = .mistake                 // the existing-but-unused case, finally produced
        q.mastery = item.mastery            // carry over forgetting-curve progress
        q.nextReviewAt = item.nextReviewAt
        q.createdAt = Date()
        return q
    }
}
