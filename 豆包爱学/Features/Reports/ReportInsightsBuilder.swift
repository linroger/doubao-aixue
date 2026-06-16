//
//  ReportInsightsBuilder.swift
//  豆包爱学 — Features/Reports
//
//  Builds the enhanced `ReportInsights` (rolling-average time, 错题攻克 trend,
//  知识掌握分布) from the same raw @Query results the core `ReportBuilder`
//  consumes. Kept @MainActor because it reads @Model accessors; the produced
//  value is Sendable and model-free so the view can hold it across the period
//  toggle. This is purely additive — `ReportBuilder` is untouched.
//

import Foundation

/// Stateless builder for the richer charts that sit alongside the core report.
@MainActor
enum ReportInsightsBuilder {

    /// Class/cohort target for the 掌握率 reference line. A steady, encouraging
    /// 80% bar that weak subjects visibly fall short of.
    static let masteryTarget: Double = 0.8

    static func make(
        period: ReportPeriod,
        report: LearningReport,
        masteries: [MasteryRecord],
        mistakes: [MistakeItem],
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> ReportInsights {
        let rolling = buildRollingTime(report: report)
        let trend = buildMistakeTrend(
            period: period, mistakes: mistakes, reference: reference, calendar: calendar)
        let distribution = buildMasteryDistribution(masteries: masteries)
        return ReportInsights(
            rollingTime: rolling,
            mistakeTrend: trend,
            masteryDistribution: distribution,
            masteryTarget: masteryTarget)
    }

    // MARK: - Rolling average over the existing time buckets

    /// Computes a trailing rolling average over the report's time buckets. The
    /// window is min(7, bucketCount) so 日(1)/周(7)/月(weekly) all read sensibly:
    /// it smooths spiky day bars into a 7 日均线-style trend.
    private static func buildRollingTime(report: LearningReport) -> [ReportRollingPoint] {
        let buckets = report.timeBuckets
        guard !buckets.isEmpty else { return [] }
        let window = min(7, buckets.count)

        return buckets.enumerated().map { index, bucket in
            let lower = max(0, index - window + 1)
            let slice = buckets[lower...index]
            let avg = slice.reduce(0.0) { $0 + $1.minutes } / Double(slice.count)
            return ReportRollingPoint(
                date: bucket.date,
                minutes: bucket.minutes,
                rollingAverage: avg,
                isCurrent: bucket.isCurrent)
        }
    }

    // MARK: - 错题攻克 trend

    /// Buckets mistakes by their creation date (新增) and by their last-reviewed
    /// date (复习) across the same calendar windows the time chart uses, so the
    /// 错题攻克 trend lines up visually with 学习时长.
    private static func buildMistakeTrend(
        period: ReportPeriod,
        mistakes: [MistakeItem],
        reference: Date,
        calendar: Calendar
    ) -> [ReportMistakeTrendPoint] {
        if period.groupsByWeek {
            let weekCount = 5
            let startOfToday = calendar.startOfDay(for: reference)
            return (0..<weekCount).reversed().map { back -> ReportMistakeTrendPoint in
                let bucketStart = calendar.date(
                    byAdding: .day, value: -(back * 7 + 6), to: startOfToday) ?? startOfToday
                let bucketEnd = calendar.date(
                    byAdding: .day, value: -(back * 7), to: startOfToday) ?? startOfToday
                let upper = calendar.date(byAdding: .day, value: 1, to: bucketEnd) ?? bucketEnd
                let added = mistakes.filter {
                    $0.createdAt >= bucketStart && $0.createdAt < upper
                }.count
                let reviewed = mistakes.filter {
                    guard let r = $0.lastReviewedAt else { return false }
                    return r >= bucketStart && r < upper
                }.count
                return ReportMistakeTrendPoint(
                    date: bucketStart, added: added, reviewed: reviewed, isCurrent: back == 0)
            }
        }

        let dayCount = max(1, period.dayBucketCount)
        let startOfToday = calendar.startOfDay(for: reference)
        return (0..<dayCount).reversed().map { back -> ReportMistakeTrendPoint in
            let day = calendar.date(byAdding: .day, value: -back, to: startOfToday) ?? startOfToday
            let added = mistakes.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count
            let reviewed = mistakes.filter {
                guard let r = $0.lastReviewedAt else { return false }
                return calendar.isDate(r, inSameDayAs: day)
            }.count
            return ReportMistakeTrendPoint(
                date: day, added: added, reviewed: reviewed,
                isCurrent: calendar.isDateInToday(day))
        }
    }

    // MARK: - 知识掌握分布 donut

    /// Counts tracked knowledge points per `MasteryState` so the donut shows the
    /// 新学 / 薄弱 / 巩固中 / 已掌握 balance. Returns slices in fixed state order
    /// and drops empty bands so the donut has no zero-area wedges.
    private static func buildMasteryDistribution(masteries: [MasteryRecord]) -> [ReportMasterySlice] {
        guard !masteries.isEmpty else { return [] }
        var counts: [MasteryState: Int] = [:]
        for record in masteries {
            counts[record.state, default: 0] += 1
        }
        let order: [MasteryState] = [.new, .weak, .developing, .mastered]
        return order.compactMap { state in
            let count = counts[state] ?? 0
            return count > 0 ? ReportMasterySlice(state: state, count: count) : nil
        }
    }
}
