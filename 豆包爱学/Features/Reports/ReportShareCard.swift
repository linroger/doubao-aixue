//
//  ReportShareCard.swift
//  豆包爱学 — Features/Reports
//
//  A polished, self-contained 学情周报 card designed to be rasterized by
//  `ImageRenderer` for ShareLink. Because the rendered image has no live
//  environment, this view takes everything it needs by value and uses only
//  fixed (non-environment) styling. It deliberately avoids @Query / @Environment
//  so it renders identically off-screen.
//
//  Layout is a fixed-width portrait card (好分享到家长群 / 朋友圈) summarising
//  时长 · 掌握率 · 错题, plus 优势学科 / 薄弱点预警 / 学习建议.
//

import SwiftUI

/// Fixed-size, value-driven card used both as an on-screen preview and as the
/// source for the shared PNG.
struct ReportShareCard: View {
    let report: LearningReport
    let topSubjects: [ReportSubjectMastery]
    let weakPoints: [ReportWeakPoint]
    let suggestions: [ReportSuggestion]
    let masteryDistribution: [ReportMasterySlice]

    /// The fixed canvas width — a comfortable share aspect on phones.
    static let canvasWidth: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            headline
            statRow
            if !masteryDistribution.isEmpty {
                distributionBar
            }
            if !topSubjects.isEmpty {
                strengthsBlock
            }
            if !weakPoints.isEmpty {
                weakBlock
            }
            if !suggestions.isEmpty {
                suggestionBlock
            }
            footer
        }
        .padding(22)
        .frame(width: Self.canvasWidth, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.dbBackground, Color.dbBackgroundAlt],
                startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            DBAvatar(name: report.learnerName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(report.learnerName)的\(report.period.fullName)学情周报")
                    .font(.dbHeadline)
                    .foregroundStyle(Color.dbTextPrimary)
                if !report.gradeLabel.isEmpty {
                    Text(report.gradeLabel)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                }
            }
            Spacer(minLength: 0)
            DBMascot(mood: report.overallMasteryRate >= 0.8 ? .cheering : .happy, size: 40)
        }
    }

    private var headline: some View {
        Text(report.headline)
            .font(.dbCallout)
            .foregroundStyle(Color.dbTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Stats

    private var statRow: some View {
        HStack(spacing: 10) {
            statTile(
                value: "\(Int(report.totalMinutes.rounded()))",
                unit: "分钟",
                caption: "学习时长",
                tint: .dbPrimary)
            statTile(
                value: "\(Int((report.overallMasteryRate * 100).rounded()))",
                unit: "%",
                caption: "掌握率",
                tint: .dbSuccess)
            statTile(
                value: "\(report.mistakesInPeriod)",
                unit: "道",
                caption: "新增错题",
                tint: .dbWarning)
        }
    }

    private func statTile(value: String, unit: String, caption: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.dbTitle3)
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.dbCaption2)
                    .foregroundStyle(tint.opacity(0.8))
            }
            Text(caption)
                .font(.dbCaption2)
                .foregroundStyle(Color.dbTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.dbSurface))
    }

    // MARK: - 掌握分布 mini bar

    private var distributionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("知识掌握分布")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(masteryDistribution) { slice in
                        ReportMasteryPalette.color(for: slice.state)
                            .frame(width: segmentWidth(slice, total: geo.size.width))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            HStack(spacing: 12) {
                ForEach(masteryDistribution) { slice in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ReportMasteryPalette.color(for: slice.state))
                            .frame(width: 7, height: 7)
                        Text("\(slice.state.displayName) \(slice.count)")
                            .font(.dbCaption2)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                }
            }
        }
    }

    private func segmentWidth(_ slice: ReportMasterySlice, total: CGFloat) -> CGFloat {
        let sum = masteryDistribution.reduce(0) { $0 + $1.count }
        guard sum > 0 else { return 0 }
        // Subtract inter-segment spacing so segments fill the bar without overflow.
        let spacing = CGFloat(max(0, masteryDistribution.count - 1)) * 2
        let usable = max(0, total - spacing)
        return usable * CGFloat(slice.count) / CGFloat(sum)
    }

    // MARK: - 优势学科

    private var strengthsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("优势学科", systemImage: "star.fill", tint: .dbSuccess)
            ForEach(topSubjects.prefix(2)) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(DBSubjectColor.color(for: item.subject))
                        .frame(width: 8, height: 8)
                    Text(item.subject.displayName)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextPrimary)
                    Spacer(minLength: 0)
                    Text("\(Int((item.averageScore * 100).rounded()))%")
                        .font(.dbFootnote.monospacedDigit())
                        .foregroundStyle(Color.dbSuccess)
                }
            }
        }
    }

    // MARK: - 薄弱点预警

    private var weakBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("薄弱点预警", systemImage: "exclamationmark.triangle.fill", tint: .dbWarning)
            ForEach(weakPoints.prefix(3)) { wp in
                HStack(spacing: 8) {
                    Circle()
                        .fill(wp.needsIntervention ? Color.dbError : Color.dbWarning)
                        .frame(width: 8, height: 8)
                    Text("\(wp.subject.displayName)「\(wp.name)」")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(Int((wp.score * 100).rounded()))%")
                        .font(.dbFootnote.monospacedDigit())
                        .foregroundStyle(wp.needsIntervention ? Color.dbError : Color.dbWarning)
                }
            }
        }
    }

    // MARK: - 学习建议

    private var suggestionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("学习建议", systemImage: "lightbulb.max.fill", tint: .dbPrimary)
            ForEach(suggestions.prefix(2)) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: tip.symbolName)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbPrimary)
                        .frame(width: 16)
                    Text(tip.text)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.dbCaption2)
                .foregroundStyle(Color.dbPrimary)
            Text("来自豆包爱学 · 陪你每天进步一点点")
                .font(.dbCaption2)
                .foregroundStyle(Color.dbTextTertiary)
        }
        .padding(.top, 2)
    }

    private func label(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.dbCaption)
                .foregroundStyle(tint)
            Text(title)
                .font(.dbSubheadline)
                .foregroundStyle(Color.dbTextPrimary)
        }
    }
}

/// Shared, deterministic color mapping for `MasteryState` bands so the donut,
/// the mini distribution bar, and the share card all agree.
@MainActor
enum ReportMasteryPalette {
    static func color(for state: MasteryState) -> Color {
        switch state {
        case .new: Color.dbInfo
        case .weak: Color.dbError
        case .developing: Color.dbWarning
        case .mastered: Color.dbSuccess
        }
    }
}

#Preview {
    ScrollView {
        ReportShareCard(
            report: LearningReport(
                period: .week,
                generatedAt: Date(),
                learnerName: "朵朵",
                gradeLabel: "小学 · 五年级",
                timeBuckets: [],
                kindSlices: [],
                subjectMastery: [],
                weakPoints: [],
                totalMinutes: 186,
                sessionCount: 9,
                overallMasteryRate: 0.72,
                masteredPointCount: 8,
                trackedPointCount: 14,
                mistakesInPeriod: 5,
                activeDayCount: 4),
            topSubjects: [
                ReportSubjectMastery(subject: .chinese, averageScore: 0.92, pointCount: 5, masteredCount: 4),
                ReportSubjectMastery(subject: .english, averageScore: 0.86, pointCount: 4, masteredCount: 3),
            ],
            weakPoints: [
                ReportWeakPoint(
                    knowledgePointID: "math.fraction", name: "分数运算", subject: .math,
                    score: 0.42, consecutiveExplains: 3, relatedMistakes: 3, needsIntervention: true),
            ],
            suggestions: [
                ReportSuggestion(text: "优先巩固「分数运算」，先看微课再做专项练习。", symbolName: "target"),
            ],
            masteryDistribution: [
                ReportMasterySlice(state: .weak, count: 2),
                ReportMasterySlice(state: .developing, count: 4),
                ReportMasterySlice(state: .mastered, count: 8),
            ])
        .padding()
    }
    .background(Color.dbBackground)
}
