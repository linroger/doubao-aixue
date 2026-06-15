//
//  ArithmeticResultsView.swift
//  豆包爱学 — Features/Practice/Arithmetic
//
//  The annotated results surface for 口算批改. Shows a summary bar (correct/total +
//  accuracy ring + route badge), a list of every item with a ✓ (dbSuccess) / ✗ (dbError)
//  overlay, the correctAnswer + 错因 explanation for wrong items, and action buttons:
//  「错题加入错题本」, 「举一反三」, 「再批一组」. Celebrates a perfect score with the mascot
//  and a success haptic.
//

import SwiftUI

struct ArithmeticResultsView: View {
    let graded: GradedArithmetic
    @Bindable var model: ArithmeticGradingModel
    var onAddToNotebook: () -> Void
    var onPracticeMore: () -> Void
    var onStartOver: () -> Void

    private var wrongItems: [GradedArithmeticItem] { graded.items.filter { !$0.isCorrect } }
    private var allCorrect: Bool { graded.total > 0 && graded.correctCount == graded.total }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            summaryCard
            if allCorrect {
                celebrationCard
            } else {
                wrongSummaryHeader
            }
            itemsCard
            actionButtons
        }
        .onAppear {
            if allCorrect { HapticEngine.play(.success) }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        DBCard(fill: allCorrect ? .dbSuccessSoft : .dbSurface) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.lg) {
                    DBProgressRing(
                        progress: model.accuracy,
                        lineWidth: 11,
                        tint: allCorrect ? .dbSuccess : .dbPrimary,
                        label: "\(Int((model.accuracy * 100).rounded()))%"
                    )
                    .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text(allCorrect ? "全对啦！" : "批改完成")
                            .font(.dbTitle3)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text("正确率 \(Int((model.accuracy * 100).rounded()))%")
                            .font(.dbSubheadline)
                            .foregroundStyle(Color.dbTextSecondary)
                        DBRouteBadge(graded.route)
                            .padding(.top, DBSpacing.xxs)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: DBSpacing.sm) {
                    DBValueStat(
                        value: "\(graded.correctCount)",
                        caption: "答对",
                        systemImage: "checkmark.circle.fill",
                        tint: .dbSuccess
                    )
                    DBValueStat(
                        value: "\(graded.total - graded.correctCount)",
                        caption: "答错",
                        systemImage: "xmark.circle.fill",
                        tint: .dbError
                    )
                    DBValueStat(
                        value: "\(graded.total)",
                        caption: "总题数",
                        systemImage: "number.circle.fill",
                        tint: .dbPrimary
                    )
                }
            }
        }
    }

    private var celebrationCard: some View {
        DBCard(fill: .dbSuccessSoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: .cheering, size: 72)
                VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                    Text("太棒了，全部正确！")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("继续保持这股劲头，来挑战更难一组吧～")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var wrongSummaryHeader: some View {
        HStack(spacing: DBSpacing.sm) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.dbWarning)
            Text("有 \(wrongItems.count) 道做错了，点开看看错因，订正后会更扎实。")
                .font(.dbSubheadline)
                .foregroundStyle(Color.dbTextSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DBSpacing.xs)
    }

    // MARK: - Items

    private var itemsCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("逐题批改", subtitle: "✓ 正确 · ✗ 待订正", systemImage: "list.bullet.rectangle.portrait.fill")
                ForEach(Array(graded.items.enumerated()), id: \.element.id) { index, item in
                    GradedItemRow(index: index + 1, item: item)
                    if item.id != graded.items.last?.id {
                        Divider().overlay(Color.dbSeparator)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: DBSpacing.sm) {
            if !wrongItems.isEmpty {
                Button(action: onAddToNotebook) {
                    Label(
                        model.savedToNotebook ? "已加入错题本（\(model.lastSavedCount) 题）" : "错题加入错题本",
                        systemImage: model.savedToNotebook ? "checkmark.circle.fill" : "book.closed.fill"
                    )
                }
                .buttonStyle(.db(.primary, fullWidth: true))
                .disabled(model.savedToNotebook)
                .opacity(model.savedToNotebook ? 0.6 : 1)
            }

            HStack(spacing: DBSpacing.sm) {
                Button(action: onPracticeMore) {
                    Label("举一反三", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.db(.secondary, fullWidth: true))

                Button(action: onStartOver) {
                    Label("再批一组", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.db(.ghost, fullWidth: true))
            }
        }
    }
}

// MARK: - One graded row

private struct GradedItemRow: View {
    let index: Int
    let item: GradedArithmeticItem

    @State private var expanded = false

    private var isWrong: Bool { !item.isCorrect }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            Button {
                if isWrong {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
            } label: {
                HStack(spacing: DBSpacing.md) {
                    statusBadge
                    VStack(alignment: .leading, spacing: 2) {
                        MathText("\(item.expression) = \(item.studentAnswer.isEmpty ? "?" : item.studentAnswer)",
                                 font: .dbBodyEmph)
                            .foregroundStyle(item.isCorrect ? Color.dbTextPrimary : Color.dbError)
                        if isWrong {
                            Text("正确答案：\(item.correctAnswer)")
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbSuccess)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("第 \(index) 题")
                        .font(.dbCaption2)
                        .foregroundStyle(Color.dbTextTertiary)
                    if isWrong {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isWrong && expanded {
                explanationBlock
            }
        }
        .padding(.vertical, DBSpacing.xxs)
    }

    private var statusBadge: some View {
        ZStack {
            Circle()
                .fill(item.isCorrect ? Color.dbSuccessSoft : Color.dbErrorSoft)
                .frame(width: 30, height: 30)
            Image(systemName: item.isCorrect ? "checkmark" : "xmark")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(item.isCorrect ? Color.dbSuccess : Color.dbError)
        }
        .accessibilityLabel(item.isCorrect ? "正确" : "错误")
    }

    private var explanationBlock: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            if let errorType = item.errorType {
                DBTag(errorType.displayName, tint: .dbError)
            }
            Text(item.explanation.isEmpty ? "正确答案是 \(item.correctAnswer)，再算一遍试试～" : item.explanation)
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            MathText("\(item.expression) = \(item.correctAnswer)", font: .dbCallout)
                .foregroundStyle(Color.dbSuccess)
        }
        .padding(DBSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbErrorSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
        .padding(.leading, 42)
    }
}

// MARK: - Preview

#Preview("批改结果") {
    let sample = GradedArithmetic(items: [
        GradedArithmeticItem(expression: "12 + 7", studentAnswer: "19", correctAnswer: "19", isCorrect: true),
        GradedArithmeticItem(expression: "8 × 9", studentAnswer: "72", correctAnswer: "72", isCorrect: true),
        GradedArithmeticItem(expression: "45 ÷ 5", studentAnswer: "8", correctAnswer: "9",
                             isCorrect: false, errorType: .calculation,
                             explanation: "正确答案是 9。45 ÷ 5 表示把 45 平均分成 5 份。"),
        GradedArithmeticItem(expression: "100 - 37", studentAnswer: "63", correctAnswer: "63", isCorrect: true),
        GradedArithmeticItem(expression: "6 × 7 + 3", studentAnswer: "45", correctAnswer: "45", isCorrect: true),
    ], route: .mock)

    return ScrollView {
        ArithmeticResultsView(
            graded: sample,
            model: ArithmeticGradingModel(),
            onAddToNotebook: {},
            onPracticeMore: {},
            onStartOver: {}
        )
        .padding()
    }
    .background(Color.dbBackground)
}
