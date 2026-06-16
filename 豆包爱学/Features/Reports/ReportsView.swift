//
//  ReportsView.swift
//  豆包爱学 — Features/Reports
//
//  学习报告 dashboard (RESEARCH F48/F55). Aggregates ActivityLog + MasteryRecord
//  + KnowledgePointEntity + MistakeItem into a parent/student-facing report and
//  renders it with Swift Charts:
//    · 学习时长 bar chart (日/周/月 toggle)
//    · 掌握率 by-subject bars + 趋势 trend line
//    · 薄弱点预警 cards → router.navigate(.knowledgePoint) / openTool(.drill)
//    · 学情周报 ShareLink summary card
//
//  Wired to AppSection.reports / Route.reports / ToolKind.reports. The shell
//  owns the NavigationStack, so this view only sets a title and returns content.
//

import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query(sort: \ActivityLog.date, order: .forward) private var logs: [ActivityLog]
    @Query private var masteries: [MasteryRecord]
    @Query private var knowledgePoints: [KnowledgePointEntity]
    @Query private var mistakes: [MistakeItem]
    @Query private var profiles: [LearnerProfile]

    @State private var period: ReportPeriod = .week
    @State private var sharePreview = false

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {}

    private var isRegular: Bool { sizeClass != .compact }

    private var profile: LearnerProfile? { profiles.first }

    private var learnerName: String { profile?.nickname ?? "小学员" }

    private var gradeLabel: String {
        guard let profile else { return "" }
        return "\(profile.stage.displayName) · \(profile.grade.displayName)"
    }

    /// The aggregated report for the current period. Rebuilt whenever the period
    /// toggle changes or the underlying @Query results update.
    private var report: LearningReport {
        ReportBuilder.make(
            period: period,
            logs: logs,
            masteries: masteries,
            knowledgePoints: knowledgePoints,
            mistakes: mistakes,
            learnerName: learnerName,
            gradeLabel: gradeLabel)
    }

    /// The richer, additive insights (rolling average, 错题攻克 trend, 掌握分布).
    /// Rebuilt alongside `report` whenever the period or @Query data changes.
    private func insights(for report: LearningReport) -> ReportInsights {
        ReportInsightsBuilder.make(
            period: period,
            report: report,
            masteries: masteries,
            mistakes: mistakes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                periodPicker
                let report = report
                if report.hasInsufficientData {
                    insufficientState
                } else {
                    summaryCard(report)
                    timeSection(report)
                    masterySection(report)
                    if !report.weakPoints.isEmpty {
                        weakPointSection(report)
                    }
                    suggestionSection(report)
                }
            }
            .padding(DBSpacing.screenInset)
        }
        .background(Color.dbBackground)
        .navigationTitle("学习报告")
    }

    // MARK: - Period toggle

    private var periodPicker: some View {
        Picker("统计周期", selection: $period) {
            ForEach(ReportPeriod.allCases) { p in
                Text(p.displayName).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Insufficient data

    private var insufficientState: some View {
        DBStateView(
            kind: .empty,
            title: "还没有足够的学习记录",
            message: "\(learnerName)\(period.fullName)还没有学习数据。先去拍一道题、听写一组词，报告就会丰富起来啦～",
            systemImage: "chart.bar.doc.horizontal")
        .frame(maxWidth: .infinity)
        .frame(minHeight: 320)
    }

    // MARK: - Summary / share card

    private func summaryCard(_ report: LearningReport) -> some View {
        DBCard(elevation: .medium) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(alignment: .center, spacing: DBSpacing.md) {
                    DBAvatar(name: learnerName, size: 48)
                    VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                        Text("\(learnerName)的\(period.fullName)学情周报")
                            .font(.dbHeadline)
                            .foregroundStyle(Color.dbTextPrimary)
                        if !gradeLabel.isEmpty {
                            Text(gradeLabel)
                                .font(.dbCaption)
                                .foregroundStyle(Color.dbTextSecondary)
                        }
                    }
                    Spacer()
                    DBMascot(mood: report.overallMasteryRate >= 0.8 ? .cheering : .happy, size: 44)
                }

                Text(report.headline)
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DBSpacing.md) {
                    DBValueStat(
                        value: "\(Int(report.totalMinutes.rounded()))",
                        caption: "学习分钟",
                        systemImage: "clock.fill",
                        tint: .dbPrimary)
                    DBValueStat(
                        value: "\(Int((report.overallMasteryRate * 100).rounded()))%",
                        caption: "掌握率",
                        systemImage: "checkmark.seal.fill",
                        tint: .dbSuccess)
                    DBValueStat(
                        value: "\(report.mistakesInPeriod)",
                        caption: "新增错题",
                        systemImage: "book.closed.fill",
                        tint: .dbWarning)
                }

                ShareLink(
                    item: ReportBuilder.shareText(for: report),
                    subject: Text("\(learnerName)的\(period.fullName)学情周报"),
                    message: Text("来自豆包爱学的学习报告")
                ) {
                    Label("分享学情周报", systemImage: "square.and.arrow.up")
                        .font(.dbBodyEmph)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.db(.secondary, fullWidth: true))
            }
        }
    }

    // MARK: - 学习时长

    private func timeSection(_ report: LearningReport) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader(
                "学习时长",
                subtitle: "活跃 \(report.activeDayCount) 天 · 日均 \(Int(report.averageMinutesPerActiveDay.rounded())) 分钟",
                systemImage: "clock.badge.checkmark.fill")
            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.md) {
                    if report.totalMinutes <= 0 {
                        emptyChartHint("\(period.fullName)还没有学习时长记录")
                    } else {
                        timeChart(report)
                        if !report.kindSlices.isEmpty {
                            kindLegend(report)
                        }
                    }
                }
            }
        }
    }

    private func timeChart(_ report: LearningReport) -> some View {
        Chart(report.timeBuckets) { bucket in
            BarMark(
                x: .value("日期", bucket.date, unit: bucketUnit),
                y: .value("分钟", bucket.minutes),
                width: .ratio(0.6))
            .foregroundStyle(bucket.isCurrent ? Color.dbPrimary : Color.dbPrimarySoft)
            .cornerRadius(DBRadius.xs)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: bucketUnit)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(bucketAxisLabel(for: date))
                            .font(.dbCaption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))")
                            .font(.dbCaption2)
                    }
                }
            }
        }
        .frame(height: 200)
        .accessibilityLabel("学习时长图表")
    }

    private var bucketUnit: Calendar.Component {
        period.groupsByWeek ? .weekOfYear : .day
    }

    private func bucketAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func kindLegend(_ report: LearningReport) -> some View {
        DBFlowLayout(spacing: DBSpacing.xs) {
            ForEach(report.kindSlices) { slice in
                DBChip(
                    "\(slice.kind.displayName) \(Int(slice.minutes.rounded()))分",
                    systemImage: slice.kind.symbolName,
                    tint: .dbSecondary,
                    isSelected: false)
            }
        }
    }

    // MARK: - 掌握率

    private func masterySection(_ report: LearningReport) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader(
                "知识点掌握",
                subtitle: "已掌握 \(report.masteredPointCount)/\(report.trackedPointCount) 个知识点",
                systemImage: "chart.bar.xaxis")
            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.lg) {
                    if report.subjectMastery.isEmpty {
                        emptyChartHint("还没有学科掌握度数据，多做几次练习就有啦")
                    } else {
                        masteryBySubjectChart(report)
                    }
                    masteryTrendBlock(report)
                }
            }
        }
    }

    private func masteryBySubjectChart(_ report: LearningReport) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            Text("各学科掌握率")
                .font(.dbSubheadline)
                .foregroundStyle(Color.dbTextSecondary)
            Chart(report.subjectMastery) { item in
                BarMark(
                    x: .value("掌握率", item.averageScore),
                    y: .value("学科", item.subject.displayName))
                .foregroundStyle(DBSubjectColor.color(for: item.subject))
                .cornerRadius(DBRadius.xs)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(Int((item.averageScore * 100).rounded()))%")
                        .font(.dbCaption2)
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
            .chartXScale(domain: 0...1)
            .chartXAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let ratio = value.as(Double.self) {
                            Text("\(Int(ratio * 100))%")
                                .font(.dbCaption2)
                        }
                    }
                }
            }
            .frame(height: max(120, CGFloat(report.subjectMastery.count) * 44))
            .accessibilityLabel("各学科掌握率图表")
        }
    }

    /// A small趋势 line tying study minutes to a rising trend across the period.
    private func masteryTrendBlock(_ report: LearningReport) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            Text("学习投入趋势")
                .font(.dbSubheadline)
                .foregroundStyle(Color.dbTextSecondary)
            if report.timeBuckets.allSatisfy({ $0.minutes <= 0 }) {
                emptyChartHint("\(period.fullName)的投入趋势会随着学习逐渐显现")
            } else {
                Chart(report.timeBuckets) { bucket in
                    LineMark(
                        x: .value("日期", bucket.date, unit: bucketUnit),
                        y: .value("分钟", bucket.minutes))
                    .foregroundStyle(Color.dbAccent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("日期", bucket.date, unit: bucketUnit),
                        y: .value("分钟", bucket.minutes))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.dbAccent.opacity(0.28), Color.dbAccent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", bucket.date, unit: bucketUnit),
                        y: .value("分钟", bucket.minutes))
                    .foregroundStyle(Color.dbAccent)
                    .symbolSize(bucket.isCurrent ? 80 : 28)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: bucketUnit)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(bucketAxisLabel(for: date))
                                    .font(.dbCaption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("学习投入趋势图表")
            }
        }
    }

    // MARK: - 薄弱点预警

    private func weakPointSection(_ report: LearningReport) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader(
                "薄弱点预警",
                subtitle: "点击查看知识点或开始专项练习",
                systemImage: "exclamationmark.triangle.fill")
            VStack(spacing: DBSpacing.cardGap) {
                ForEach(report.weakPoints) { weak in
                    weakPointCard(weak)
                }
            }
        }
    }

    private func weakPointCard(_ weak: ReportWeakPoint) -> some View {
        DBCard(fill: weak.needsIntervention ? Color.dbErrorSoft : Color.dbSurface) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(alignment: .top, spacing: DBSpacing.sm) {
                    VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                        Text(weak.name)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(2)
                        HStack(spacing: DBSpacing.xs) {
                            DBSubjectChip(weak.subject)
                            if weak.relatedMistakes > 0 {
                                DBTag("\(weak.relatedMistakes) 道错题", tint: .dbWarning)
                            }
                            if weak.needsIntervention {
                                DBTag("急需巩固", tint: .dbError)
                            }
                        }
                    }
                    Spacer()
                    DBProgressRing(
                        progress: weak.score,
                        lineWidth: 6,
                        tint: weak.needsIntervention ? .dbError : .dbWarning,
                        label: "\(Int((weak.score * 100).rounded()))%")
                    .frame(width: 52, height: 52)
                }

                HStack(spacing: DBSpacing.sm) {
                    Button {
                        router.navigate(.knowledgePoint(weak.knowledgePointID), regular: isRegular)
                    } label: {
                        Label("看知识点", systemImage: "lightbulb.fill")
                            .font(.dbFootnote)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.db(.ghost))

                    Button {
                        router.openDrill(knowledgePointID: weak.knowledgePointID, regular: isRegular)
                    } label: {
                        Label("专项练习", systemImage: "square.grid.3x3.fill")
                            .font(.dbFootnote)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.db(.primary))
                }
            }
        }
    }

    // MARK: - 学习建议

    private func suggestionSection(_ report: LearningReport) -> some View {
        let tips = ReportBuilder.suggestions(for: report)
        return Group {
            if tips.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    DBSectionHeader("学习建议", systemImage: "lightbulb.max.fill")
                    DBCard {
                        VStack(alignment: .leading, spacing: DBSpacing.md) {
                            ForEach(tips) { tip in
                                HStack(alignment: .top, spacing: DBSpacing.sm) {
                                    Image(systemName: tip.symbolName)
                                        .font(.dbBody)
                                        .foregroundStyle(Color.dbPrimary)
                                        .frame(width: 24)
                                    Text(tip.text)
                                        .font(.dbCallout)
                                        .foregroundStyle(Color.dbTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyChartHint(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: DBSpacing.sm) {
                Image(systemName: "chart.bar")
                    .font(.dbTitle2)
                    .foregroundStyle(Color.dbTextTertiary)
                Text(message)
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(minHeight: 120)
    }
}

#Preview {
    NavigationStack { ReportsView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
}
