//
//  ReportBuilder.swift
//  豆包爱学 — Features/Reports
//
//  Aggregates raw SwiftData models (ActivityLog + MasteryRecord + MistakeItem +
//  KnowledgePointEntity) into an immutable `LearningReport` for the requested
//  period. Kept @MainActor because it reads @Model accessors; the produced
//  `LearningReport` value is Sendable and free of model references so the view
//  can hold it across the period toggle without retaining the store.
//

import Foundation

/// Stateless builder. Call `make(...)` with the @Query results and a period.
@MainActor
enum ReportBuilder {

    static func make(
        period: ReportPeriod,
        logs: [ActivityLog],
        masteries: [MasteryRecord],
        knowledgePoints: [KnowledgePointEntity],
        mistakes: [MistakeItem],
        learnerName: String,
        gradeLabel: String,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> LearningReport {
        let start = period.startDate(relativeTo: reference, calendar: calendar)
        let logsInPeriod = logs.filter { $0.date >= start && $0.date <= reference }

        let timeBuckets = buildTimeBuckets(
            period: period, logs: logsInPeriod, reference: reference, calendar: calendar)
        let kindSlices = buildKindSlices(logs: logsInPeriod)

        let nameByID = Dictionary(
            knowledgePoints.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        let subjectMastery = buildSubjectMastery(masteries: masteries)
        let weakPoints = buildWeakPoints(
            masteries: masteries, nameByID: nameByID, mistakes: mistakes)

        let totalMinutes = logsInPeriod.reduce(0.0) { $0 + $1.minutes }
        let activeDays = Set(logsInPeriod.map { calendar.startOfDay(for: $0.date) }).count

        let trackedPointCount = masteries.count
        let masteredPointCount = masteries.filter { $0.state == .mastered }.count
        let overallRate = trackedPointCount > 0
            ? masteries.reduce(0.0) { $0 + $1.score } / Double(trackedPointCount)
            : 0

        let mistakesInPeriod = mistakes.filter { $0.createdAt >= start && $0.createdAt <= reference }.count

        return LearningReport(
            period: period,
            generatedAt: reference,
            learnerName: learnerName,
            gradeLabel: gradeLabel,
            timeBuckets: timeBuckets,
            kindSlices: kindSlices,
            subjectMastery: subjectMastery,
            weakPoints: weakPoints,
            totalMinutes: totalMinutes,
            sessionCount: logsInPeriod.count,
            overallMasteryRate: overallRate,
            masteredPointCount: masteredPointCount,
            trackedPointCount: trackedPointCount,
            mistakesInPeriod: mistakesInPeriod,
            activeDayCount: activeDays
        )
    }

    // MARK: - Time buckets

    private static func buildTimeBuckets(
        period: ReportPeriod,
        logs: [ActivityLog],
        reference: Date,
        calendar: Calendar
    ) -> [ReportTimeBucket] {
        if period.groupsByWeek {
            // 月 view → group the trailing ~30 days into 5 weekly columns.
            let weekCount = 5
            let startOfToday = calendar.startOfDay(for: reference)
            return (0..<weekCount).reversed().map { back -> ReportTimeBucket in
                let bucketStart = calendar.date(
                    byAdding: .day, value: -(back * 7 + 6), to: startOfToday) ?? startOfToday
                let bucketEnd = calendar.date(
                    byAdding: .day, value: -(back * 7), to: startOfToday) ?? startOfToday
                let upper = calendar.date(byAdding: .day, value: 1, to: bucketEnd) ?? bucketEnd
                let minutes = logs
                    .filter { $0.date >= bucketStart && $0.date < upper }
                    .reduce(0.0) { $0 + $1.minutes }
                return ReportTimeBucket(date: bucketStart, minutes: minutes, isCurrent: back == 0)
            }
        }

        let dayCount = max(1, period.dayBucketCount)
        let startOfToday = calendar.startOfDay(for: reference)
        return (0..<dayCount).reversed().map { back -> ReportTimeBucket in
            let day = calendar.date(byAdding: .day, value: -back, to: startOfToday) ?? startOfToday
            let minutes = logs
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.minutes }
            return ReportTimeBucket(
                date: day, minutes: minutes, isCurrent: calendar.isDateInToday(day))
        }
    }

    // MARK: - Kind breakdown

    private static func buildKindSlices(logs: [ActivityLog]) -> [ReportKindSlice] {
        var totals: [ReportActivityKind: Double] = [:]
        for log in logs {
            let kind = ReportActivityKind(raw: log.kindRaw)
            totals[kind, default: 0] += max(0, log.minutes)
        }
        return totals
            .filter { $0.value > 0 }
            .map { ReportKindSlice(kind: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
    }

    // MARK: - Subject mastery

    private static func buildSubjectMastery(masteries: [MasteryRecord]) -> [ReportSubjectMastery] {
        let grouped = Dictionary(grouping: masteries, by: { $0.subject })
        return grouped
            .map { subject, records -> ReportSubjectMastery in
                let avg = records.reduce(0.0) { $0 + $1.score } / Double(max(1, records.count))
                let mastered = records.filter { $0.state == .mastered }.count
                return ReportSubjectMastery(
                    subject: subject,
                    averageScore: avg,
                    pointCount: records.count,
                    masteredCount: mastered)
            }
            .sorted { lhs, rhs in
                // Lowest mastery first so weak subjects surface at a glance,
                // but keep a stable subject order on ties.
                if abs(lhs.averageScore - rhs.averageScore) > 0.001 {
                    return lhs.averageScore < rhs.averageScore
                }
                return lhs.subject.displayName < rhs.subject.displayName
            }
    }

    // MARK: - Weak points

    private static func buildWeakPoints(
        masteries: [MasteryRecord],
        nameByID: [String: String],
        mistakes: [MistakeItem]
    ) -> [ReportWeakPoint] {
        // Count mistakes per knowledge point for richer alert context.
        var mistakeCount: [String: Int] = [:]
        for mistake in mistakes {
            for kp in mistake.knowledgePointIDs {
                mistakeCount[kp, default: 0] += 1
            }
        }

        return masteries
            .filter { $0.score < 0.6 }   // 薄弱 / 巩固中 边界
            .sorted { $0.score < $1.score }
            .prefix(6)
            .map { record -> ReportWeakPoint in
                let name = nameByID[record.knowledgePointID]
                    ?? fallbackName(for: record.knowledgePointID)
                let needs = record.consecutiveExplains >= 3 || record.score < 0.35
                return ReportWeakPoint(
                    knowledgePointID: record.knowledgePointID,
                    name: name,
                    subject: record.subject,
                    score: record.score,
                    consecutiveExplains: record.consecutiveExplains,
                    relatedMistakes: mistakeCount[record.knowledgePointID] ?? 0,
                    needsIntervention: needs)
            }
    }

    /// Best-effort readable name when a knowledge-point entity is missing.
    private static func fallbackName(for id: String) -> String {
        let tail = id.split(separator: ".").last.map(String.init) ?? id
        return tail.isEmpty ? id : tail
    }

    // MARK: - Suggestions

    /// Derives 2–4 coaching lines from the report. Pure, deterministic.
    static func suggestions(for report: LearningReport) -> [ReportSuggestion] {
        var result: [ReportSuggestion] = []

        if let weakest = report.weakPoints.first {
            result.append(ReportSuggestion(
                text: "优先巩固「\(weakest.name)」（\(weakest.subject.displayName)），现掌握 \(Int((weakest.score * 100).rounded()))%，建议先看微课再做专项练习。",
                symbolName: "target"))
        }

        if report.totalMinutes <= 0 {
            result.append(ReportSuggestion(
                text: "\(report.period.fullName)还没有学习记录，先用 10 分钟拍一道题或听写一组词热个身吧。",
                symbolName: "play.circle.fill"))
        } else {
            let avg = Int(report.averageMinutesPerActiveDay.rounded())
            result.append(ReportSuggestion(
                text: "学习日均 \(avg) 分钟，保持每天一点点，效果比突击更好。",
                symbolName: "clock.badge.checkmark.fill"))
        }

        if report.mistakesInPeriod > 0 {
            result.append(ReportSuggestion(
                text: "\(report.period.fullName)新增 \(report.mistakesInPeriod) 道错题，记得在错题本里趁热复习，避免遗忘。",
                symbolName: "book.closed.fill"))
        }

        if report.overallMasteryRate >= 0.8 && !report.hasInsufficientData {
            result.append(ReportSuggestion(
                text: "整体掌握率已达 \(Int((report.overallMasteryRate * 100).rounded()))%，可以尝试更有挑战的拓展题啦！",
                symbolName: "star.fill"))
        }

        return result
    }

    /// Builds the plain-text body for the ShareLink 学情周报.
    static func shareText(for report: LearningReport) -> String {
        var lines: [String] = []
        lines.append("📊 \(report.learnerName)的\(report.period.fullName)学情周报")
        lines.append(report.gradeLabel)
        lines.append("")
        lines.append(report.headline)
        lines.append("")
        lines.append("· 学习时长：\(Int(report.totalMinutes.rounded())) 分钟（\(report.activeDayCount) 个活跃学习日）")
        lines.append("· 知识点掌握率：\(Int((report.overallMasteryRate * 100).rounded()))%（已掌握 \(report.masteredPointCount)/\(report.trackedPointCount) 个）")
        lines.append("· 新增错题：\(report.mistakesInPeriod) 道")

        if !report.weakPoints.isEmpty {
            lines.append("")
            lines.append("⚠️ 薄弱点提醒：")
            for wp in report.weakPoints.prefix(3) {
                lines.append("· \(wp.subject.displayName)「\(wp.name)」掌握 \(Int((wp.score * 100).rounded()))%")
            }
        }

        let tips = suggestions(for: report)
        if !tips.isEmpty {
            lines.append("")
            lines.append("💡 学习建议：")
            for tip in tips.prefix(3) {
                lines.append("· \(tip.text)")
            }
        }

        lines.append("")
        lines.append("—— 来自豆包爱学")
        return lines.joined(separator: "\n")
    }
}
