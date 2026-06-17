//
//  DrillRunnerViews.swift
//  豆包爱学 — Features/Practice/Drill
//
//  The two interactive surfaces of the 靶向练习 runner, factored out of `DrillView`:
//
//    • `DrillRunnerCard`  — one problem at a time: progress ring + 第 N / M counter,
//                           the question (MathText), the answer input (typed / iOS
//                           handwriting), a 「检查」 button, then a verdict banner with
//                           the revealed `SolutionStep`s and a 「下一题 / 看结果」 button.
//    • `DrillResultsView` — the finish screen: accuracy ring, mascot celebration,
//                           per-question recap, and 「再练一组」 / 「完成」.
//
//  Both bind to the shared `DrillModel` (the single source of truth) and never compute
//  correctness themselves. Math-bearing text uses `MathText`. Dark Mode via Color.db*.
//

import SwiftUI
import SwiftData

// MARK: - Runner card

struct DrillRunnerCard: View {
    @Bindable var model: DrillModel
    let problem: GeneratedProblem
    let subject: Subject

    private var total: Int { model.problems.count }
    private var humanIndex: Int { model.currentIndex + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            progressHeader
            questionCard
            if !model.hasChecked {
                answerSection
                checkButton
            } else {
                verdictBanner
                solutionCard
                advanceButton
            }
        }
    }

    // MARK: Progress

    private var progressHeader: some View {
        HStack(spacing: DBSpacing.md) {
            DBProgressRing(
                progress: Double(model.currentIndex) / Double(max(total, 1)),
                lineWidth: 7,
                tint: .dbPrimary,
                label: "\(humanIndex)/\(total)"
            )
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(humanIndex) 题 · 共 \(total) 题")
                    .font(.dbCallout.weight(.medium))
                    .foregroundStyle(Color.dbTextPrimary)
                Text("已答对 \(model.correctCount) 题，继续加油！")
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
            DBTag("难度 \(difficultyStars)", tint: .dbSecondary)
        }
    }

    private var difficultyStars: String {
        String(repeating: "★", count: max(1, min(5, problem.difficulty)))
    }

    // MARK: Question

    private var questionCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Label("题目", systemImage: "text.book.closed.fill")
                    .font(.dbCaption.weight(.semibold))
                    .foregroundStyle(Color.dbTextTertiary)
                if subject.isSTEM {
                    MathText(problem.question, font: .dbTitle3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(problem.question)
                        .font(.dbTitle3)
                        .foregroundStyle(Color.dbTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Answer input

    private var answerSection: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Label("你的答案", systemImage: "pencil.line")
                    .font(.dbCaption.weight(.semibold))
                    .foregroundStyle(Color.dbTextTertiary)
                DrillAnswerInput(
                    answer: $model.typedAnswer,
                    subject: subject,
                    isLocked: false,
                    onSubmit: { if canCheck { model.check() } }
                )
            }
        }
    }

    private var canCheck: Bool {
        !model.typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var checkButton: some View {
        Button {
            model.check()
        } label: {
            Label("检查", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.db(.primary, fullWidth: true))
        .disabled(!canCheck)
    }

    // MARK: Verdict + solution

    private var verdictBanner: some View {
        HStack(spacing: DBSpacing.md) {
            Image(systemName: model.currentIsCorrect ? "checkmark.seal.fill" : "lightbulb.fill")
                .font(.dbTitle2)
                .foregroundStyle(model.currentIsCorrect ? Color.dbSuccess : Color.dbWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.currentIsCorrect ? "答对啦！" : "再看看解析")
                    .font(.dbHeadline)
                    .foregroundStyle(Color.dbTextPrimary)
                if !model.currentIsCorrect {
                    answerLine(label: "正确答案", value: problem.answer, tint: .dbSuccess)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (model.currentIsCorrect ? Color.dbSuccessSoft : Color.dbWarning.opacity(0.14)),
            in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
        )
    }

    @ViewBuilder
    private func answerLine(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: DBSpacing.xs) {
            Text("\(label)：")
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
            if subject.isSTEM {
                MathText(value, font: .dbCallout).foregroundStyle(tint)
            } else {
                Text(value).font(.dbCallout).foregroundStyle(tint)
            }
        }
    }

    private var solutionCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("解题步骤", systemImage: "list.bullet.rectangle.portrait.fill")
                if problem.steps.isEmpty {
                    answerLine(label: "答案", value: problem.answer, tint: .dbTextPrimary)
                } else {
                    ForEach(problem.steps, id: \.index) { step in
                        DrillStepRow(step: step, isSTEM: subject.isSTEM)
                        if step.index != problem.steps.last?.index {
                            Divider().overlay(Color.dbSeparator)
                        }
                    }
                }
            }
        }
    }

    private var advanceButton: some View {
        Button {
            model.advance()
        } label: {
            Label(model.isLastProblem ? "查看结果" : "下一题",
                  systemImage: model.isLastProblem ? "flag.checkered" : "arrow.right")
        }
        .buttonStyle(.db(.primary, fullWidth: true))
    }
}

// MARK: - One solution step

/// Renders a single `SolutionStep`: title + detail, with the optional `math` line shown
/// via `MathText`. Used in the runner's revealed solution and the results recap.
struct DrillStepRow: View {
    let step: SolutionStep
    var isSTEM: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Text("\(step.index + 1)")
                .font(.dbFootnote.weight(.bold))
                .foregroundStyle(Color.dbOnPrimary)
                .frame(width: 22, height: 22)
                .background(Color.dbPrimary, in: Circle())
            VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                if !step.title.isEmpty {
                    Text(step.title)
                        .font(.dbCallout.weight(.semibold))
                        .foregroundStyle(Color.dbTextPrimary)
                }
                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let math = step.math, !math.isEmpty {
                    MathText(math, font: .dbCallout)
                        .foregroundStyle(Color.dbTextPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DBSpacing.xxs)
    }
}

// MARK: - Results

struct DrillResultsView: View {
    @Bindable var model: DrillModel
    var onPracticeAgain: () -> Void
    var onFinish: () -> Void
    var onAddToNotebook: () -> Void = {}

    private var percent: Int { Int((model.accuracy * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            summaryCard
            recapCard
            actionButtons
        }
    }

    private var summaryCard: some View {
        DBCard(fill: model.allCorrect ? .dbSuccessSoft : .dbSurface, elevation: .medium) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.lg) {
                    DBProgressRing(
                        progress: model.accuracy,
                        lineWidth: 11,
                        tint: model.allCorrect ? .dbSuccess : .dbPrimary,
                        label: "\(percent)%"
                    )
                    .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        DBMascot(mood: model.allCorrect ? .cheering : .happy, size: 52)
                        Text(headline)
                            .font(.dbTitle3)
                            .foregroundStyle(Color.dbTextPrimary)
                    }
                    Spacer(minLength: 0)
                }

                Text(encouragement)
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DBSpacing.sm) {
                    DBValueStat(value: "\(model.correctCount)", caption: "答对",
                                systemImage: "checkmark.circle.fill", tint: .dbSuccess)
                    DBValueStat(value: "\(model.outcomes.count - model.correctCount)", caption: "答错",
                                systemImage: "xmark.circle.fill", tint: .dbError)
                    DBValueStat(value: "\(model.outcomes.count)", caption: "总题数",
                                systemImage: "number.circle.fill", tint: .dbPrimary)
                }
            }
        }
    }

    private var headline: String {
        if model.allCorrect { return "全部答对！" }
        if model.accuracy >= 0.6 { return "练习完成" }
        return "再接再厉"
    }

    private var encouragement: String {
        if let name = model.selectedTarget?.name {
            if model.allCorrect {
                return "「\(name)」这组题全部拿下，掌握度已经更新，继续保持～"
            } else if model.accuracy >= 0.6 {
                return "「\(name)」掌握得不错，把做错的几题的解析再看一遍会更稳。"
            } else {
                return "「\(name)」还需要多练几组，订正错题后掌握度会慢慢提升。"
            }
        }
        return "本组练习已完成，掌握度已经更新。"
    }

    private var recapCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("逐题回顾", subtitle: "✓ 答对 · ✗ 待订正",
                                systemImage: "list.bullet.clipboard.fill")
                ForEach(Array(model.outcomes.enumerated()), id: \.element.id) { index, outcome in
                    DrillRecapRow(index: index + 1, outcome: outcome,
                                  isSTEM: (model.selectedTarget?.subject ?? .math).isSTEM)
                    if outcome.id != model.outcomes.last?.id {
                        Divider().overlay(Color.dbSeparator)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DBSpacing.sm) {
            if !model.wrongOutcomes.isEmpty {
                Button(action: onAddToNotebook) {
                    Label(model.allWrongSaved
                          ? "已加入错题本（\(model.savedMistakeProblemIDs.count) 题）"
                          : "错题加入错题本",
                          systemImage: model.allWrongSaved ? "checkmark.circle.fill" : "book.closed.fill")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
                .disabled(model.allWrongSaved)
                .opacity(model.allWrongSaved ? 0.6 : 1)
            }

            Button(action: onPracticeAgain) {
                Label("再练一组", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.db(model.wrongOutcomes.isEmpty ? .primary : .secondary, fullWidth: true))

            Button(action: onFinish) {
                Label("查看学习报告", systemImage: "chart.bar.doc.horizontal.fill")
            }
            .buttonStyle(.db(.ghost, fullWidth: true))
        }
    }
}

// MARK: - One recap row

private struct DrillRecapRow: View {
    let index: Int
    let outcome: DrillOutcome
    var isSTEM: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DBSpacing.md) {
            ZStack {
                Circle()
                    .fill(outcome.isCorrect ? Color.dbSuccessSoft : Color.dbErrorSoft)
                    .frame(width: 28, height: 28)
                Image(systemName: outcome.isCorrect ? "checkmark" : "xmark")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(outcome.isCorrect ? Color.dbSuccess : Color.dbError)
            }
            VStack(alignment: .leading, spacing: 2) {
                questionLine
                if !outcome.isCorrect {
                    valueLine(label: "你的答案", value: outcome.typedAnswer.isEmpty ? "未作答" : outcome.typedAnswer, tint: .dbError)
                    valueLine(label: "正确答案", value: outcome.correctAnswer, tint: .dbSuccess)
                }
            }
            Spacer(minLength: 0)
            Text("第 \(index) 题")
                .font(.dbCaption2)
                .foregroundStyle(Color.dbTextTertiary)
        }
        .padding(.vertical, DBSpacing.xxs)
    }

    @ViewBuilder
    private var questionLine: some View {
        if isSTEM {
            MathText(outcome.question, font: .dbCallout).lineLimit(2)
        } else {
            Text(outcome.question)
                .font(.dbCallout)
                .foregroundStyle(Color.dbTextPrimary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func valueLine(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: DBSpacing.xxs) {
            Text("\(label)：")
                .font(.dbCaption2)
                .foregroundStyle(Color.dbTextTertiary)
            if isSTEM {
                MathText(value, font: .dbCaption).foregroundStyle(tint)
            } else {
                Text(value).font(.dbCaption2).foregroundStyle(tint)
            }
        }
    }
}

// MARK: - Previews

#Preview("解题运行器") {
    let model = DrillModel()
    NavigationStack {
        ScrollView {
            DrillRunnerCard(
                model: model,
                problem: GeneratedProblem(
                    question: "解方程：2x + 5 = 17",
                    answer: "x = 6",
                    steps: [
                        SolutionStep(index: 0, title: "移项", detail: "把常数 5 移到右边", math: "2x = 17 - 5"),
                        SolutionStep(index: 1, title: "化简", detail: "计算右边", math: "2x = 12"),
                        SolutionStep(index: 2, title: "求解", detail: "两边同除以 2", math: "x = 6")
                    ],
                    difficulty: 2,
                    knowledgePointID: "math.equation"
                ),
                subject: .math
            )
            .padding()
        }
        .background(Color.dbBackground)
        .navigationTitle("举一反三")
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
