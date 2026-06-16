//
//  EssayFeedbackView.swift
//  豆包爱学 — Features/Practice/Essay
//
//  Praising-first feedback presenter for 作文批改 (F31). Renders, in product order:
//    1. 综合点评 — overall comment + 闪光点 chips (always praises first).
//    2. 评分 — DBProgressRing gauge + per-维度 雷达图 (default) / 条形图 toggle over
//       RubricDimensions, with a per-维度 breakdown.
//    3. 分句点评 — scrollable list of SentenceAnnotation, colour-coded by severity
//       (.praise 绿 / .suggestion 琥珀 / .error 红) with optional 修改建议.
//    4. 升格作文 — 原文/升格 toggle with newly-added content highlighted (EssayDiff);
//       gated behind a parent verification when 学习模式 is on ("coach, don't write").
//    5. 高分表达 — chips of reusable strong phrases.
//    6. 朗读修改 — read the overall comment / polished essay aloud (TTS).
//    7. 同类练手题 — CTA back into the tutor.
//
//  Pure presentation; all data is the `EssayFeedback` payload plus the original
//  text. Full Dark Mode via semantic Color.db*; Charts import is local to this file.
//

import SwiftUI
import Charts

struct EssayFeedbackView: View {
    let feedback: EssayFeedback
    let originalText: String
    let subject: Subject
    let examTypeName: String
    let isRegular: Bool
    let modelEssayUnlocked: Bool

    /// (text, BCP-47 language) — caller picks zh-CN / en-US per subject.
    var onSpeak: (String, String) -> Void
    var onStopSpeak: () -> Void
    var onUnlockModelEssay: () -> Void
    var onPracticeSameType: () -> Void
    var onBackToEditing: () -> Void

    /// 升格作文 side-by-side (regular width) vs toggle (compact).
    @State private var showingPolished = true
    /// 评分可视化: 雷达图 (default, when ≥3 维度) 或 条形图.
    @State private var rubricChartStyle: RubricChartStyle = .radar

    private var speechLanguage: String { subject == .english ? "en-US" : "zh-CN" }

    private var isEnglish: Bool { subject == .english }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            headerBar
            overallCard
            scoreCard
            annotationsCard
            polishedCard
            if !feedback.highScoreExpressions.isEmpty {
                highScoreCard
            }
            actionsCard
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: DBSpacing.sm) {
            Button {
                onStopSpeak()
                onBackToEditing()
            } label: {
                Label("继续修改", systemImage: "arrow.uturn.backward")
                    .font(.dbSubheadline)
            }
            .buttonStyle(.db(.ghost))

            Spacer()

            if !examTypeName.isEmpty {
                DBTag(examTypeName, tint: .dbSecondary)
            }
            DBRouteBadge(feedback.route)
        }
    }

    // MARK: - 综合点评 (praise first)

    private var overallCard: some View {
        DBCard(fill: .dbSuccessSoft, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.sm) {
                    DBMascot(mood: .cheering, size: 52)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("综合点评").font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
                        Text("先看闪光点，再看怎么变更好").font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                    }
                }

                Text(feedback.overallComment)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !feedback.strengths.isEmpty {
                    DBFlowLayout(spacing: DBSpacing.xs) {
                        ForEach(feedback.strengths, id: \.self) { strength in
                            DBChip(strength, systemImage: "sparkle", tint: .dbSuccess)
                        }
                    }
                    .padding(.top, DBSpacing.xxs)
                }
            }
        }
    }

    // MARK: - 评分

    private var scoreCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("评分", subtitle: examTypeName.isEmpty ? "各维度得分一览" : "参照\(examTypeName)评分标准", systemImage: "gauge.with.dots.needle.67percent")

                HStack(alignment: .center, spacing: DBSpacing.lg) {
                    DBProgressRing(
                        progress: feedback.maxScore > 0 ? feedback.score / feedback.maxScore : 0,
                        lineWidth: 12,
                        tint: scoreTint,
                        label: "\(Int(feedback.score.rounded()))"
                    )
                    .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text("\(Int(feedback.score.rounded())) / \(Int(feedback.maxScore.rounded())) 分")
                            .font(.dbTitle2.monospacedDigit())
                            .foregroundStyle(Color.dbTextPrimary)
                        Text(scoreBlurb)
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                if !feedback.rubric.isEmpty {
                    rubricChartSection
                    rubricBreakdown
                }
            }
        }
    }

    /// Radar (default) vs bar visualisation of the rubric, with a small segmented
    /// switch when both make sense. Radar needs ≥3 维度 to read as a polygon, so
    /// for 1–2 维度 we always fall back to the bar chart.
    @ViewBuilder private var rubricChartSection: some View {
        let canRadar = EssayRadarChart.canRender(feedback.rubric)
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            if canRadar {
                Picker("评分图表样式", selection: $rubricChartStyle) {
                    Label("雷达图", systemImage: "chart.dots.scatter").tag(RubricChartStyle.radar)
                    Label("条形图", systemImage: "chart.bar.fill").tag(RubricChartStyle.bar)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("评分图表样式")
            }

            if canRadar && rubricChartStyle == .radar {
                EssayRadarChart(dimensions: feedback.rubric, tint: scoreTint)
                    .frame(maxWidth: .infinity)
            } else {
                rubricBarChart
            }
        }
    }

    private var rubricBarChart: some View {
        Chart(feedback.rubric) { dim in
            BarMark(
                x: .value("得分", dim.score),
                y: .value("维度", dim.name)
            )
            .foregroundStyle(barTint(for: dim))
            .cornerRadius(DBRadius.xs)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(Int(dim.score.rounded()))/\(Int(dim.maxScore.rounded()))")
                    .font(.dbCaption2.monospacedDigit())
                    .foregroundStyle(Color.dbTextTertiary)
            }
        }
        .chartXScale(domain: 0...(feedback.rubric.map(\.maxScore).max() ?? 20))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading) { _ in
                AxisValueLabel()
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextSecondary)
            }
        }
        .frame(height: CGFloat(feedback.rubric.count) * 36 + 12)
        .accessibilityLabel("各维度评分条形图")
    }

    private var rubricBreakdown: some View {
        VStack(spacing: DBSpacing.sm) {
            ForEach(feedback.rubric) { dim in
                HStack(alignment: .top, spacing: DBSpacing.sm) {
                    Circle()
                        .fill(barTint(for: dim))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(dim.name).font(.dbSubheadline).foregroundStyle(Color.dbTextPrimary)
                            Spacer()
                            Text("\(Int(dim.score.rounded())) / \(Int(dim.maxScore.rounded()))")
                                .font(.dbFootnote.monospacedDigit())
                                .foregroundStyle(Color.dbTextSecondary)
                        }
                        if !dim.comment.isEmpty {
                            Text(dim.comment).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 分句点评

    private var annotationsCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("分句点评",
                                subtitle: "逐句看：绿色是亮点，琥珀是建议，红色要修改",
                                systemImage: "text.line.first.and.arrowtriangle.forward")

                if feedback.annotations.isEmpty {
                    Text("这篇作文整体表达流畅，没有需要特别标注的句子，继续保持！")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                } else {
                    VStack(spacing: DBSpacing.sm) {
                        ForEach(feedback.annotations) { annotation in
                            SentenceAnnotationRow(annotation: annotation)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 升格作文

    private var polishedCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("升格作文",
                                subtitle: modelEssayUnlocked ? "对照看看哪里被升格了" : "学习模式开启：先思考，再看范文",
                                systemImage: "wand.and.stars") {
                    if modelEssayUnlocked, !isRegular {
                        Picker("视图", selection: $showingPolished) {
                            Text("升格").tag(true)
                            Text("原文").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                }

                if modelEssayUnlocked {
                    polishedBody
                } else {
                    lockedPolished
                }

                Label("升格作文供你对照学习，请用自己的话改写，不要照抄。",
                      systemImage: "lightbulb.fill")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextTertiary)
            }
        }
    }

    @ViewBuilder private var polishedBody: some View {
        if isRegular {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("原文").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                    Text(originalText)
                        .font(.dbBody)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DBSpacing.sm)
                        .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                }
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("升格（高亮为新增/改写）").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                    polishedHighlightText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DBSpacing.sm)
                        .background(Color.dbPrimarySoft.opacity(0.4), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                }
            }
        } else {
            if showingPolished {
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("高亮为升格新增/改写的部分").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                    polishedHighlightText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DBSpacing.sm)
                        .background(Color.dbPrimarySoft.opacity(0.4), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                }
            } else {
                Text(originalText)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DBSpacing.sm)
                    .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
            }
        }
    }

    /// Polished text with model-introduced runs highlighted (EssayDiff).
    private var polishedHighlightText: Text {
        let segments = EssayDiff.segments(original: originalText, polished: feedback.polishedText)
        guard !segments.isEmpty else {
            return Text(feedback.polishedText).foregroundColor(.dbTextPrimary)
        }
        // Build one AttributedString so additions render coral/bold inline —
        // the modern replacement for the deprecated `Text + Text` concatenation.
        var attributed = AttributedString()
        for segment in segments {
            var piece = AttributedString(segment.text)
            switch segment.kind {
            case .same:
                piece.foregroundColor = .dbTextPrimary
            case .added:
                piece.foregroundColor = .dbPrimaryDeep
                piece.font = .dbBody.weight(.semibold)
            }
            attributed.append(piece)
        }
        return Text(attributed).font(.dbBody)
    }

    private var lockedPolished: some View {
        VStack(spacing: DBSpacing.sm) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.dbSecondary)
            Text("升格范文已为你准备好")
                .font(.dbBodyEmph)
                .foregroundStyle(Color.dbTextPrimary)
            Text("为了让你先独立思考，完整升格作文需要家长确认后查看。")
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
                .multilineTextAlignment(.center)
            Button {
                onUnlockModelEssay()
            } label: {
                Label("家长确认后查看", systemImage: "person.badge.key.fill")
            }
            .buttonStyle(.db(.secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DBSpacing.md)
        .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
    }

    // MARK: - 高分表达

    private var highScoreCard: some View {
        DBCard(fill: .dbSecondarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader(isEnglish ? "高分表达" : "高分表达 · 好词好句",
                                subtitle: "下次写作可以试着用上",
                                systemImage: "star.bubble.fill")
                DBFlowLayout(spacing: DBSpacing.xs) {
                    ForEach(feedback.highScoreExpressions, id: \.self) { phrase in
                        DBChip(phrase, systemImage: "quote.opening", tint: .dbSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Actions (朗读 / 练手题)

    private var actionsCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("继续学习", systemImage: "graduationcap.fill")

                DBFlowLayout(spacing: DBSpacing.sm) {
                    Button {
                        onSpeak(feedback.overallComment, speechLanguage)
                    } label: {
                        Label("朗读点评", systemImage: "speaker.wave.2.fill")
                            .font(.dbSubheadline)
                    }
                    .buttonStyle(.db(.secondary))

                    if modelEssayUnlocked, !feedback.polishedText.isEmpty {
                        Button {
                            onSpeak(feedback.polishedText, speechLanguage)
                        } label: {
                            Label("朗读升格作文", systemImage: "text.bubble.fill")
                                .font(.dbSubheadline)
                        }
                        .buttonStyle(.db(.ghost))
                    }

                    Button {
                        onStopSpeak()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                            .font(.dbSubheadline)
                    }
                    .buttonStyle(.db(.ghost))
                }

                Button {
                    onPracticeSameType()
                } label: {
                    Label("练一道同类作文", systemImage: "pencil.and.outline")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
            }
        }
    }

    // MARK: - Helpers

    private var scoreFraction: Double {
        feedback.maxScore > 0 ? feedback.score / feedback.maxScore : 0
    }

    private var scoreTint: Color {
        switch scoreFraction {
        case 0.85...: .dbSuccess
        case 0.6..<0.85: .dbPrimary
        default: .dbWarning
        }
    }

    private var scoreBlurb: String {
        switch scoreFraction {
        case 0.85...: "很棒！整体水平优秀，再打磨细节就更出彩。"
        case 0.7..<0.85: "不错的发挥，按建议修改还能再上一个台阶。"
        case 0.6..<0.7: "基础扎实，重点关注下方的修改建议。"
        default: "别灰心，跟着分句点评一步步改，进步会很快。"
        }
    }

    private func barTint(for dim: RubricDimension) -> Color {
        let fraction = dim.maxScore > 0 ? dim.score / dim.maxScore : 0
        switch fraction {
        case 0.85...: return .dbSuccess
        case 0.6..<0.85: return .dbPrimary
        default: return .dbWarning
        }
    }
}

// MARK: - Rubric chart style

/// Which visualisation the 评分 card shows for the rubric dimensions.
private enum RubricChartStyle: Hashable {
    case radar
    case bar
}

// MARK: - Sentence annotation row

private struct SentenceAnnotationRow: View {
    let annotation: SentenceAnnotation

    var body: some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                HStack(spacing: DBSpacing.xs) {
                    Image(systemName: symbol)
                        .font(.dbCaption)
                        .foregroundStyle(tint)
                    Text(severityLabel)
                        .font(.dbCaption2.weight(.semibold))
                        .foregroundStyle(tint)
                    Spacer(minLength: 0)
                }

                Text("“\(annotation.original)”")
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(annotation.comment)
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let suggestion = annotation.suggestion, !suggestion.isEmpty {
                    HStack(alignment: .top, spacing: DBSpacing.xs) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.dbCaption2)
                            .foregroundStyle(Color.dbPrimary)
                        Text(suggestion)
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbPrimaryDeep)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(DBSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dbPrimarySoft.opacity(0.5), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                }
            }
        }
        .padding(DBSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
    }

    private var tint: Color {
        switch annotation.severity {
        case .praise: .dbSuccess
        case .suggestion: .dbWarning
        case .error: .dbError
        }
    }

    private var symbol: String {
        switch annotation.severity {
        case .praise: "hand.thumbsup.fill"
        case .suggestion: "lightbulb.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var severityLabel: String {
        switch annotation.severity {
        case .praise: "亮点"
        case .suggestion: "建议"
        case .error: "需修改"
        }
    }
}

// MARK: - Preview

#Preview("作文反馈") {
    let sample = EssayFeedback(
        overallComment: "先表扬：你的作文中心明确、条理清楚，看得出认真思考。再建议：个别句子可以更具体生动，结尾可以呼应开头、升华主题。",
        score: 86, maxScore: 100,
        rubric: [
            RubricDimension(name: "立意", score: 18, maxScore: 20, comment: "中心明确，能围绕主题展开。"),
            RubricDimension(name: "结构", score: 16, maxScore: 20, comment: "层次较清晰，段落衔接可再自然。"),
            RubricDimension(name: "语言", score: 15, maxScore: 20, comment: "用词较准确，可增加生动表达。"),
            RubricDimension(name: "书写", score: 18, maxScore: 20, comment: "卷面整洁，标点规范。"),
            RubricDimension(name: "亮点", score: 14, maxScore: 20, comment: "有自己的思考，鼓励再深入。")
        ],
        annotations: [
            SentenceAnnotation(original: "我的理想是成为一名科学家。", comment: "开头点题，很好！", severity: .praise),
            SentenceAnnotation(original: "科学家可以探索未知。", comment: "这句可以更具体，加入细节描写。",
                               suggestion: "科学家可以探索浩瀚的星空与微观的细胞，为人类解开一个又一个未知之谜。", severity: .suggestion),
            SentenceAnnotation(original: "我相信理想一定会实现。", comment: "结尾略平，可呼应开头升华。", severity: .error)
        ],
        polishedText: "我的理想是成为一名探索宇宙奥秘的科学家。每当我仰望浩瀚星空，总会被无尽的未知深深吸引。科学家可以探索浩瀚的星空与微观的细胞，为人类解开一个又一个未知之谜。为了实现这个理想，我要认真学习，勤于思考，遇到困难也绝不轻言放弃。我坚信，只要持之以恒地努力，理想终将照进现实。",
        highScoreExpressions: ["首尾呼应", "由景及情", "画龙点睛", "持之以恒"],
        strengths: ["中心明确", "条理清楚", "书写工整"]
    )

    return ScrollView {
        EssayFeedbackView(
            feedback: sample,
            originalText: ContentCatalog.sampleEssay,
            subject: .chinese,
            examTypeName: "中考",
            isRegular: false,
            modelEssayUnlocked: true,
            onSpeak: { _, _ in },
            onStopSpeak: {},
            onUnlockModelEssay: {},
            onPracticeSameType: {},
            onBackToEditing: {}
        )
        .padding(DBSpacing.screenInset)
    }
    .background(Color.dbBackground)
    .environment(TTSService())
}
