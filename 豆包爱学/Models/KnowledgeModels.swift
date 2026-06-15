//
//  KnowledgeModels.swift
//  豆包爱学
//
//  Knowledge points and per-learner mastery (知识图谱 / 掌握度).
//

import Foundation
import SwiftData

@Model
public final class KnowledgePointEntity {
    public var id: String = UUID().uuidString
    public var name: String = ""
    public var subjectRaw: String = Subject.math.rawValue
    public var gradeRaw: Int = GradeLevel.g5.rawValue
    public var summary: String = ""
    public var parentIDs: [String] = []
    public var relatedIDs: [String] = []
    public var chapter: String = ""

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .general }
        set { subjectRaw = newValue.rawValue }
    }
    public var grade: GradeLevel {
        get { GradeLevel(rawValue: gradeRaw) ?? .g5 }
        set { gradeRaw = newValue.rawValue }
    }
}

@Model
public final class MasteryRecord {
    public var id: UUID = UUID()
    public var knowledgePointID: String = ""
    public var subjectRaw: String = Subject.math.rawValue
    public var score: Double = 0           // 0...1
    public var attempts: Int = 0
    public var correctCount: Int = 0
    public var consecutiveExplains: Int = 0  // for 薄弱点预警 (3 → push micro-course)
    public var lastUpdated: Date = Date()

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .general }
        set { subjectRaw = newValue.rawValue }
    }
    public var state: MasteryState {
        switch score {
        case ..<0.2: .new
        case ..<0.5: .weak
        case ..<0.85: .developing
        default: .mastered
        }
    }
}
