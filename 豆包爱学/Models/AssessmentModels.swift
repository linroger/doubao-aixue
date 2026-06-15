//
//  AssessmentModels.swift
//  豆包爱学
//
//  Essay grading records and practice sessions/attempts.
//

import Foundation
import SwiftData

@Model
public final class EssayRecord {
    public var id: UUID = UUID()
    public var subjectRaw: String = Subject.chinese.rawValue
    public var title: String = ""
    public var promptText: String = ""
    public var originalText: String = ""
    public var overallComment: String = ""
    public var score: Double = 0
    public var maxScore: Double = 100
    public var examType: String = ""               // 中考 / 高考 / IELTS …
    public var rubricData: Data? = nil             // [RubricDimension]
    public var annotationsData: Data? = nil        // [SentenceAnnotation]
    public var polishedText: String = ""           // 升格作文
    public var highScoreExpressions: [String] = []
    public var createdAt: Date = Date()

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .chinese }
        set { subjectRaw = newValue.rawValue }
    }
    public var rubric: [RubricDimension] {
        get { DBJSON.decode([RubricDimension].self, from: rubricData) ?? [] }
        set { rubricData = DBJSON.encode(newValue) }
    }
    public var annotations: [SentenceAnnotation] {
        get { DBJSON.decode([SentenceAnnotation].self, from: annotationsData) ?? [] }
        set { annotationsData = DBJSON.encode(newValue) }
    }
}

@Model
public final class PracticeSession {
    public var id: UUID = UUID()
    public var subjectRaw: String = Subject.math.rawValue
    public var title: String = "今日靶向练习"
    public var kindRaw: String = "targeted"        // targeted / drill / similar
    public var targetKnowledgePointIDs: [String] = []
    public var totalCount: Int = 0
    public var correctCount: Int = 0
    public var estMinutes: Int = 8
    public var completed: Bool = false
    public var createdAt: Date = Date()
    public var completedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \PracticeAttempt.session)
    public var attempts: [PracticeAttempt]? = []

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .math }
        set { subjectRaw = newValue.rawValue }
    }
    public var progress: Double {
        totalCount == 0 ? 0 : Double(correctCount) / Double(totalCount)
    }
}

@Model
public final class PracticeAttempt {
    public var id: UUID = UUID()
    public var questionText: String = ""
    public var answer: String = ""
    public var correctAnswer: String = ""
    public var isCorrect: Bool = false
    public var knowledgePointID: String = ""
    public var timeSpent: TimeInterval = 0
    public var session: PracticeSession? = nil

    public init() {}
}
