//
//  PlanAndActivity.swift
//  豆包爱学
//
//  Study plans, reminders, activity log, streaks, parent controls.
//

import Foundation
import SwiftData

@Model
public final class StudyPlan {
    public var id: UUID = UUID()
    public var title: String = "我的学习计划"
    public var subjectRaw: String? = nil
    public var targetMinutesPerDay: Int = 20
    public var knowledgePointIDs: [String] = []
    public var active: Bool = true
    public var createdAt: Date = Date()

    public init() {}

    public var subject: Subject? {
        get { subjectRaw.flatMap(Subject.init(rawValue:)) }
        set { subjectRaw = newValue?.rawValue }
    }
}

@Model
public final class StudyReminder {
    public var id: UUID = UUID()
    public var title: String = ""
    public var hour: Int = 19
    public var minute: Int = 30
    public var enabled: Bool = true
    public var kindRaw: String = "review"          // review / practice / checkIn
    public var createdAt: Date = Date()

    public init() {}
}

@Model
public final class ActivityLog {
    public var id: UUID = UUID()
    public var kindRaw: String = "solve"           // solve / tutor / practice / dictation / essay …
    public var subjectRaw: String? = nil
    public var detail: String = ""
    public var minutes: Double = 0
    /// Number of questions answered / graded / practiced in this event. Drives the
    /// daily contribution heatmap ("答题足迹"). Time-only activity (e.g. 专注) is 0.
    public var count: Int = 0
    public var date: Date = Date()

    public init() {}

    public var subject: Subject? {
        get { subjectRaw.flatMap(Subject.init(rawValue:)) }
        set { subjectRaw = newValue?.rawValue }
    }
}

@Model
public final class StudyStreak {
    public var id: UUID = UUID()
    public var current: Int = 0
    public var longest: Int = 0
    public var lastCheckIn: Date? = nil

    public init() {}
}

@Model
public final class ParentControls {
    public var id: UUID = UUID()
    public var verified: Bool = false
    public var hideSolutionSteps: Bool = false     // 隐藏答案/只看思路
    public var gateEssayReveal: Bool = true        // 作文范文需家长验证
    public var dailyTimeLimitMinutes: Int = 0      // 0 = no limit
    public var weeklyReportEnabled: Bool = true
    public var updatedAt: Date = Date()

    public init() {}
}
