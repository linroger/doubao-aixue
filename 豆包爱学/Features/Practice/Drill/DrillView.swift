//
//  DrillView.swift
//  豆包爱学 — Features/Practice/Drill
//
//  举一反三 / 靶向练习 (RESEARCH F47/F48). Wired to `ToolKind.drill`. Three phases,
//  all driven by `DrillModel`:
//
//    • setup    — a hero card with today's 靶向练习 (the weakest `MasteryRecord`),
//                 an estimated-minutes pill, a question-count stepper, and a subject /
//                 knowledge-point picker so the learner can target anything.
//    • running  — a one-at-a-time problem runner: a progress ring, the `GeneratedProblem`
//                 rendered with `MathText`, a typed (iOS PencilKit) answer input, a
//                 「检查」 button that reveals the `SolutionStep`s, then 「下一题」.
//    • finished — an accuracy ring, per-question recap, mascot celebration, and
//                 「再练一组」 / 「完成」. On reaching this phase the model updates the
//                 target `MasteryRecord` and inserts a `PracticeSession` + attempts.
//
//  Pushed view: no NavigationStack here — sets .navigationTitle, returns content.
//  Handles every state (no targets, generating, generation error, empty). Full Dark
//  Mode via semantic Color.db*; PencilKit guarded so macOS uses the typed field.
//

import SwiftUI
import SwiftData

struct DrillView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query private var profiles: [LearnerProfile]
    @Query private var masteries: [MasteryRecord]
    @Query private var knowledgePoints: [KnowledgePointEntity]

    @State private var model = DrillModel()

    /// When non-nil, the drill opens already focused on this knowledge point
    /// (deep-linked from a weak point, a mistake, a report, or a KP screen).
    private let targetKnowledgePointID: String?

    init(targetKnowledgePointID: String? = nil) {
        self.targetKnowledgePointID = targetKnowledgePointID
    }

    private var profile: LearnerProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                switch model.phase {
                case .setup:    setupPhase
                case .running:  runnerPhase
                case .finished: finishedPhase
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("举一反三")
        .task(id: profiles.count) {
            reconfigure()
        }
        .onChange(of: masteries.count) { _, _ in reconfigure() }
    }

    private func reconfigure() {
        model.configure(
            masteries: masteries,
            knowledgePoints: knowledgePoints,
            profileGrade: profile?.grade ?? .g5,
            profileSubjects: profile?.subjects ?? [],
            preselected: targetKnowledgePointID
        )
    }

    // MARK: - Setup phase

    @ViewBuilder
    private var setupPhase: some View {
        if model.targets.isEmpty {
            DBStateView(
                kind: .empty,
                title: "还没有可练习的知识点",
                message: "做几道题或学习一些课程后，这里会根据你的薄弱点生成靶向练习。",
                systemImage: "scope"
            )
            .frame(minHeight: 280)
        } else {
            heroCard
            countStepper
            pickerSection
            generateButton
            if case .error(let message) = model.generation {
                inlineError(message)
            }
        }
    }

    private var heroCard: some View {
        DBCard(fill: .clear, elevation: .medium) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(alignment: .top, spacing: DBSpacing.md) {
                    DBMascot(mood: .thinking, size: 60)
                    VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                        Text("今日靶向练习")
                            .font(.dbTitle3)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text(heroSubtitle)
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                if let target = model.selectedTarget {
                    HStack(spacing: DBSpacing.sm) {
                        DBSubjectChip(target.subject)
                        DBTag(target.name, tint: DBSubjectColor.color(for: target.subject))
                        MasteryPill(state: target.state)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: DBSpacing.sm) {
                        Label("约 \(model.estimatedMinutes) 分钟", systemImage: "clock.fill")
                            .font(.dbCaption.weight(.medium))
                            .foregroundStyle(Color.dbPrimaryDeep)
                        Label("\(model.requestedCount) 道题", systemImage: "list.number")
                            .font(.dbCaption.weight(.medium))
                            .foregroundStyle(Color.dbSecondary)
                    }
                }
            }
            .padding(DBSpacing.xs)
        }
        .background(
            RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                .fill(Color.dbHeroGradient.opacity(0.18))
        )
    }

    private var heroSubtitle: String {
        guard let target = model.selectedTarget else {
            return "选择一个知识点，豆包来为你出一组同类题。"
        }
        switch target.state {
        case .new, .weak:
            return "「\(target.name)」还比较薄弱，集中练一组同类题，掌握得更牢～"
        case .developing:
            return "「\(target.name)」正在进步，再练一组巩固一下吧。"
        case .mastered:
            return "「\(target.name)」已经掌握得不错，挑战同类题保持手感！"
        }
    }

    private var countStepper: some View {
        DBCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("题目数量")
                        .font(.dbCallout.weight(.medium))
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("先来 \(model.requestedCount) 道，专注又不累")
                        .font(.dbCaption2)
                        .foregroundStyle(Color.dbTextTertiary)
                }
                Spacer()
                Stepper(value: $model.requestedCount, in: 3...10) {
                    Text("\(model.requestedCount)")
                        .font(.dbTitle3.monospacedDigit())
                        .foregroundStyle(Color.dbPrimaryDeep)
                }
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("选择练习知识点",
                            subtitle: "薄弱点优先，也可以挑任意学科",
                            systemImage: "scope")
            ForEach(model.targetsBySubject, id: \.subject) { group in
                DBCard {
                    VStack(alignment: .leading, spacing: DBSpacing.sm) {
                        HStack(spacing: DBSpacing.xs) {
                            Image(systemName: group.subject.symbolName)
                                .foregroundStyle(DBSubjectColor.color(for: group.subject))
                            Text(group.subject.displayName)
                                .font(.dbHeadline)
                                .foregroundStyle(Color.dbTextPrimary)
                        }
                        DBFlowLayout(spacing: DBSpacing.xs) {
                            ForEach(group.items) { target in
                                Button {
                                    HapticEngine.play(.selection)
                                    model.selectedTarget = target
                                } label: {
                                    DBChip(
                                        target.name,
                                        systemImage: model.selectedTarget?.id == target.id
                                            ? "checkmark.circle.fill" : nil,
                                        tint: DBSubjectColor.color(for: target.subject),
                                        isSelected: model.selectedTarget?.id == target.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var generateButton: some View {
        Button {
            Task { await model.generate(using: intelligence) }
        } label: {
            if case .loading = model.generation {
                HStack(spacing: DBSpacing.xs) {
                    ProgressView().tint(.dbOnPrimary)
                    Text("正在出题…")
                }
            } else {
                Label("开始练习", systemImage: "play.fill")
            }
        }
        .buttonStyle(.db(.primary, fullWidth: true))
        .disabled(model.selectedTarget == nil || isGenerating)
    }

    private var isGenerating: Bool {
        if case .loading = model.generation { return true }
        return false
    }

    private func inlineError(_ message: String) -> some View {
        HStack(spacing: DBSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.dbWarning)
            Text(message)
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .background(Color.dbWarning.opacity(0.12), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
    }

    // MARK: - Running phase

    @ViewBuilder
    private var runnerPhase: some View {
        if let problem = model.currentProblem {
            DrillRunnerCard(
                model: model,
                problem: problem,
                subject: model.selectedTarget?.subject ?? .math
            )
        } else {
            DBStateView(kind: .loading, title: "准备题目中")
                .frame(minHeight: 240)
        }
    }

    // MARK: - Finished phase

    private var finishedPhase: some View {
        DrillResultsView(
            model: model,
            onPracticeAgain: { model.restart() },
            onFinish: {
                HapticEngine.play(.light)
                router.navigate(.reports, regular: sizeClass != .compact)
            }
        )
        .onAppear {
            model.persistResults(context: context, existingMasteries: masteries)
        }
    }
}

// MARK: - Mastery pill (pure presentation)

/// Small colored capsule showing a `MasteryState` label, reused on the hero + picker.
struct MasteryPill: View {
    let state: MasteryState

    var body: some View {
        Text(state.displayName)
            .font(.dbCaption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, DBSpacing.sm)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private var tint: Color {
        switch state {
        case .new:        .dbTextTertiary
        case .weak:       .dbError
        case .developing: .dbWarning
        case .mastered:   .dbSuccess
        }
    }
}

// MARK: - Preview

#Preview("举一反三") {
    NavigationStack {
        DrillView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
