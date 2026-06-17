//
//  CourseAndDocument.swift
//  豆包爱学
//
//  豆包课堂 courses + lesson progress, and 文档/PDF 问答 documents.
//

import Foundation
import SwiftData

@Model
public final class CourseEntity {
    public var id: UUID = UUID()
    public var title: String = ""
    public var author: String = ""
    public var dynasty: String = ""
    public var subjectRaw: String = Subject.chinese.rawValue
    public var gradeRaw: Int = GradeLevel.g6.rawValue
    public var summary: String = ""
    public var durationSec: Int = 600
    public var thumbnailSymbol: String = "play.tv.fill"
    public var isUGC: Bool = false                 // 精品课程 vs 我的课程
    public var reviewVerified: Bool = true         // 三重审核
    public var generationStatusRaw: String = "ready"  // pending/generating/ready/failed
    public var segmentsData: Data? = nil           // [TutorSegment] lesson script
    public var knowledgePointIDs: [String] = []
    public var createdAt: Date = Date()

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .chinese }
        set { subjectRaw = newValue.rawValue }
    }
    public var grade: GradeLevel {
        get { GradeLevel(rawValue: gradeRaw) ?? .g6 }
        set { gradeRaw = newValue.rawValue }
    }
    public var segments: [TutorSegment] {
        get { DBJSON.decode([TutorSegment].self, from: segmentsData) ?? [] }
        set { segmentsData = DBJSON.encode(newValue) }
    }
}

@Model
public final class LessonProgress {
    public var id: UUID = UUID()
    public var courseID: UUID = UUID()
    public var lastSegmentIndex: Int = 0
    public var completed: Bool = false
    public var quizCorrect: Int = 0
    public var updatedAt: Date = Date()

    public init() {}
}

@Model
public final class DocumentEntity {
    public var id: UUID = UUID()
    public var title: String = ""
    public var fileType: String = "pdf"
    public var pageCount: Int = 1
    public var parsedText: String = ""
    public var summary: String = ""
    public var keyPoints: [String] = []
    public var outline: [String] = []
    /// Provenance of the persisted summary (端侧/增强/离线) so the route badge stays
    /// truthful when the summary is reloaded, instead of always reading 离线.
    public var summaryRouteRaw: String = IntelligenceRoute.mock.rawValue
    public var createdAt: Date = Date()

    public init() {}

    public var summaryRoute: IntelligenceRoute {
        get { IntelligenceRoute(rawValue: summaryRouteRaw) ?? .mock }
        set { summaryRouteRaw = newValue.rawValue }
    }
}
