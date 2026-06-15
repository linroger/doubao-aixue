//
//  ReportModels.swift
//  豆包爱学 — Features/Reports
//
//  Pure value types for the 学习报告 / 学情周报 dashboard (RESEARCH F48/F55).
//  These structs aggregate ActivityLog + MasteryRecord + MistakeItem into a
//  parent- and student-facing report. They are UI-free and Sendable so the
//  view layer can build them off raw @Query results cheaply on the main actor.
//

import Foundation

// MARK: - Period

/// The 日 / 周 / 月 toggle that scopes every figure in the report.
public nonisolated enum ReportPeriod: String, CaseIterable, Codable, Sendable, Identifiable {
    case day
    case week
    case month

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .day: "日"
        case .week: "周"
        case .month: "月"
        }
    }

    /// Long label used in the shareable summary headline.
    public var fullName: String {
        switch self {
        case .day: "今日"
        case .week: "本周"
        case .month: "本月"
        }
    }

    /// How many day-buckets the time chart spans for this period.
    public var dayBucketCount: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        }
    }

    /// The chart calendar unit so bars group sensibly (月 groups by week).
    public var groupsByWeek: Bool { self == .month }

    /// Inclusive lower bound for "is this log inside the period?" given today.
    public func startDate(relativeTo reference: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: reference)
        let offset = -(dayBucketCount - 1)
        return calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
    }
}

// MARK: - Activity kinds

/// Human-friendly grouping of the free-form `ActivityLog.kindRaw` string.
public nonisolated enum ReportActivityKind: String, CaseIterable, Sendable, Identifiable {
    case tutor
    case practice
    case solve
    case dictation
    case essay
    case vocabulary
    case reading
    case other

    public var id: String { rawValue }

    public init(raw: String) {
        switch raw.lowercased() {
        case "tutor", "lesson", "course", "classroom": self = .tutor
        case "practice", "drill", "quiz": self = .practice
        case "solve", "search": self = .solve
        case "dictation": self = .dictation
        case "essay", "grade", "gradeessay": self = .essay
        case "vocabulary", "word", "words": self = .vocabulary
        case "reading", "read", "classical": self = .reading
        default: self = .other
        }
    }

    public var displayName: String {
        switch self {
        case .tutor: "讲题学习"
        case .practice: "专项练习"
        case .solve: "拍题答疑"
        case .dictation: "听写默写"
        case .essay: "作文批改"
        case .vocabulary: "背单词"
        case .reading: "古诗文阅读"
        case .other: "其他"
        }
    }

    public var symbolName: String {
        switch self {
        case .tutor: "graduationcap.fill"
        case .practice: "square.grid.3x3.fill"
        case .solve: "camera.viewfinder"
        case .dictation: "ear.fill"
        case .essay: "text.badge.checkmark"
        case .vocabulary: "rectangle.on.rectangle.angled.fill"
        case .reading: "scroll.fill"
        case .other: "sparkles"
        }
    }
}

// MARK: - Aggregated buckets

/// One x-axis bucket of study minutes (a day, or a week within 月 view).
public nonisolated struct ReportTimeBucket: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date          // the bucket's representative start date
    public let minutes: Double
    public let isCurrent: Bool     // today (or current week) → highlighted

    public init(date: Date, minutes: Double, isCurrent: Bool) {
        self.date = date
        self.minutes = minutes
        self.isCurrent = isCurrent
    }
}

/// Minutes spent per activity kind, for the breakdown ring legend.
public nonisolated struct ReportKindSlice: Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public let kind: ReportActivityKind
    public let minutes: Double

    public init(kind: ReportActivityKind, minutes: Double) {
        self.kind = kind
        self.minutes = minutes
    }
}

/// Mastery rolled up for one subject (average score across its knowledge points).
public nonisolated struct ReportSubjectMastery: Identifiable, Sendable {
    public var id: String { subject.rawValue }
    public let subject: Subject
    public let averageScore: Double   // 0…1
    public let pointCount: Int
    public let masteredCount: Int

    public init(subject: Subject, averageScore: Double, pointCount: Int, masteredCount: Int) {
        self.subject = subject
        self.averageScore = averageScore
        self.pointCount = pointCount
        self.masteredCount = masteredCount
    }

    public var state: MasteryState {
        switch averageScore {
        case ..<0.2: .new
        case ..<0.5: .weak
        case ..<0.85: .developing
        default: .mastered
        }
    }
}

/// A flagged weak point that drives a 薄弱点预警 card + CTA.
public nonisolated struct ReportWeakPoint: Identifiable, Sendable {
    public var id: String { knowledgePointID }
    public let knowledgePointID: String
    public let name: String
    public let subject: Subject
    public let score: Double           // 0…1
    public let consecutiveExplains: Int
    public let relatedMistakes: Int
    public let needsIntervention: Bool // ≥3 consecutive explains → push 微课/练习

    public init(
        knowledgePointID: String,
        name: String,
        subject: Subject,
        score: Double,
        consecutiveExplains: Int,
        relatedMistakes: Int,
        needsIntervention: Bool
    ) {
        self.knowledgePointID = knowledgePointID
        self.name = name
        self.subject = subject
        self.score = score
        self.consecutiveExplains = consecutiveExplains
        self.relatedMistakes = relatedMistakes
        self.needsIntervention = needsIntervention
    }
}

// MARK: - The report

/// The fully-aggregated report for one period — everything the dashboard renders.
public nonisolated struct LearningReport: Sendable {
    public let period: ReportPeriod
    public let generatedAt: Date
    public let learnerName: String
    public let gradeLabel: String

    public let timeBuckets: [ReportTimeBucket]
    public let kindSlices: [ReportKindSlice]
    public let subjectMastery: [ReportSubjectMastery]
    public let weakPoints: [ReportWeakPoint]

    public let totalMinutes: Double
    public let sessionCount: Int
    public let overallMasteryRate: Double   // 0…1, all tracked points
    public let masteredPointCount: Int
    public let trackedPointCount: Int
    public let mistakesInPeriod: Int
    public let activeDayCount: Int

    public init(
        period: ReportPeriod,
        generatedAt: Date,
        learnerName: String,
        gradeLabel: String,
        timeBuckets: [ReportTimeBucket],
        kindSlices: [ReportKindSlice],
        subjectMastery: [ReportSubjectMastery],
        weakPoints: [ReportWeakPoint],
        totalMinutes: Double,
        sessionCount: Int,
        overallMasteryRate: Double,
        masteredPointCount: Int,
        trackedPointCount: Int,
        mistakesInPeriod: Int,
        activeDayCount: Int
    ) {
        self.period = period
        self.generatedAt = generatedAt
        self.learnerName = learnerName
        self.gradeLabel = gradeLabel
        self.timeBuckets = timeBuckets
        self.kindSlices = kindSlices
        self.subjectMastery = subjectMastery
        self.weakPoints = weakPoints
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
        self.overallMasteryRate = overallMasteryRate
        self.masteredPointCount = masteredPointCount
        self.trackedPointCount = trackedPointCount
        self.mistakesInPeriod = mistakesInPeriod
        self.activeDayCount = activeDayCount
    }

    /// True when there is essentially nothing to report yet (insufficient-data).
    public var hasInsufficientData: Bool {
        totalMinutes <= 0 && trackedPointCount == 0 && mistakesInPeriod == 0
    }

    /// Average minutes across the buckets that actually had study.
    public var averageMinutesPerActiveDay: Double {
        guard activeDayCount > 0 else { return 0 }
        return totalMinutes / Double(activeDayCount)
    }

    /// A short, encouraging headline used in the parent-facing summary card.
    public var headline: String {
        if hasInsufficientData {
            return "\(learnerName)还没有足够的学习记录，先一起开个好头吧～"
        }
        let minutes = Int(totalMinutes.rounded())
        let rate = Int((overallMasteryRate * 100).rounded())
        return "\(period.fullName)\(learnerName)累计学习 \(minutes) 分钟，知识点掌握率 \(rate)%。"
    }
}

// MARK: - Suggestions

/// A coaching suggestion line shown in 学习建议 (and the share card body).
public nonisolated struct ReportSuggestion: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let symbolName: String

    public init(text: String, symbolName: String) {
        self.text = text
        self.symbolName = symbolName
    }
}
