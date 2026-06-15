//
//  ProblemAndMistake.swift
//  豆包爱学
//
//  Solved problems (搜题历史) and the cross-cutting 错题本 (mistake notebook).
//

import Foundation
import SwiftData

/// A captured + solved problem, persisted with its solution and follow-ups.
@Model
public final class ProblemRecord {
    public var id: UUID = UUID()
    public var subjectRaw: String = Subject.math.rawValue
    public var sourceRaw: String = ProblemSource.camera.rawValue
    public var recognizedText: String = ""        // editable OCR result (may contain LaTeX)
    @Attribute(.externalStorage) public var imageData: Data? = nil
    public var solutionData: Data? = nil           // encoded [SolutionStep]
    public var choicesData: Data? = nil            // encoded [ChoiceOption] for MCQ
    public var finalAnswer: String = ""
    public var approach: String = ""               // 思路
    public var knowledgePointsData: Data? = nil    // encoded [KnowledgeRef]
    public var routeRaw: String = IntelligenceRoute.mock.rawValue
    public var savedToMistakes: Bool = false
    public var createdAt: Date = Date()

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .general }
        set { subjectRaw = newValue.rawValue }
    }
    public var source: ProblemSource {
        get { ProblemSource(rawValue: sourceRaw) ?? .camera }
        set { sourceRaw = newValue.rawValue }
    }
    public var steps: [SolutionStep] {
        get { DBJSON.decode([SolutionStep].self, from: solutionData) ?? [] }
        set { solutionData = DBJSON.encode(newValue) }
    }
    public var choices: [ChoiceOption] {
        get { DBJSON.decode([ChoiceOption].self, from: choicesData) ?? [] }
        set { choicesData = DBJSON.encode(newValue) }
    }
    public var knowledgePoints: [KnowledgeRef] {
        get { DBJSON.decode([KnowledgeRef].self, from: knowledgePointsData) ?? [] }
        set { knowledgePointsData = DBJSON.encode(newValue) }
    }
    public var route: IntelligenceRoute {
        get { IntelligenceRoute(rawValue: routeRaw) ?? .mock }
        set { routeRaw = newValue.rawValue }
    }
}

/// A wrong/difficult question collected into the 错题本.
@Model
public final class MistakeItem {
    public var id: UUID = UUID()
    public var subjectRaw: String = Subject.math.rawValue
    public var questionText: String = ""
    @Attribute(.externalStorage) public var imageData: Data? = nil
    public var studentAnswer: String = ""
    public var correctAnswer: String = ""
    public var errorReason: String = ""
    public var errorTypeRaw: String = ErrorType.careless.rawValue
    public var masteryRaw: String = MasteryState.new.rawValue
    public var knowledgePointIDs: [String] = []
    public var solutionData: Data? = nil           // encoded [SolutionStep]
    public var reviewCount: Int = 0
    public var nextReviewAt: Date = Date()
    public var lastReviewedAt: Date? = nil
    public var createdAt: Date = Date()

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .general }
        set { subjectRaw = newValue.rawValue }
    }
    public var errorType: ErrorType {
        get { ErrorType(rawValue: errorTypeRaw) ?? .careless }
        set { errorTypeRaw = newValue.rawValue }
    }
    public var mastery: MasteryState {
        get { MasteryState(rawValue: masteryRaw) ?? .new }
        set { masteryRaw = newValue.rawValue }
    }
    public var steps: [SolutionStep] {
        get { DBJSON.decode([SolutionStep].self, from: solutionData) ?? [] }
        set { solutionData = DBJSON.encode(newValue) }
    }
}
