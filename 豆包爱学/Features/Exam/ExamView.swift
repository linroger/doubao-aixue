//
//  ExamView.swift
//  豆包爱学 — Features/Exam
//
//  模拟测验 (timed practice exam) — the UI for `ExamModel`. Four phases:
//    · setup   — pick 学科 / 题量 / 时长, then 开始测验 (assembles the paper).
//    · running — one question per screen with a live countdown, progress, typed
//                answer, 上一题 / 下一题, and 交卷.
//    · timeUp  — transient bridge that auto-grades when the countdown hits 0.
//    · graded  — score ring, per-question ✓/✗ recap with revealed steps, and
//                加入错题本 for wrong items.
//
//  Wired to `ToolKind.exam` via AppDestinations.toolView. The shell owns the
//  NavigationStack, so this view only sets a title and returns content.
//

import SwiftUI
import SwiftData
import Combine

struct ExamView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var profiles: [LearnerProfile]
    @Query private var masteries: [MasteryRecord]

    @State private var model = ExamModel()
    @State private var didConfigure = false

    /// One shared 1-second tick; `model.tick()` is a no-op unless running.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {}

    private var isRegular: Bool { sizeClass != .compact }
    private var profile: LearnerProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                switch model.phase {
                case .setup:   setupPhase
                case .running: runningPhase
                case .timeUp:  timeUpPhase
                case .graded:  gradedPhase
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("模拟测验")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear(perform: configureIfNeeded)
        .onReceive(ticker) { _ in model.tick() }
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        model.configure(profileGrade: profile?.grade ?? .g5,
                        profileSubjects: profile?.subjects ?? [])
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupPhase: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: .curious, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("来一场限时小测吧").font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                    Text("选好学科、题量和时长，我来组卷并计时。交卷后自动批改、讲解、收错题。")
                        .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }

        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                DBSectionHeader("选择学科", systemImage: "books.vertical.fill")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DBSpacing.sm) {
                        ForEach(model.availableSubjects) { subject in
                            Button {
                                model.selectedSubject = subject; HapticEngine.play(.selection)
                            } label: {
                                DBSubjectChip(subject, isSelected: model.selectedSubject == subject)
                            }.buttonStyle(.plain)
                        }
                    }
                }

                Divider().overlay(Color.dbSeparator)

                HStack {
                    Label("题量", systemImage: "number.circle.fill")
                        .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                    Spacer()
                    Stepper("\(model.requestedCount) 题", value: $model.requestedCount, in: 3...15)
                        .labelsHidden()
                    Text("\(model.requestedCount) 题").font(.dbBody).foregroundStyle(Color.dbTextSecondary)
                        .frame(width: 48, alignment: .trailing)
                }

                Divider().overlay(Color.dbSeparator)

                Label("时长", systemImage: "timer")
                    .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                Picker("时长", selection: $model.duration) {
                    ForEach(ExamDuration.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }
        }

        if case .error(let message) = model.assembly {
            DBStateView(kind: .error, title: "组卷失败", message: message, retry: { startExam() })
                .frame(minHeight: 160)
        } else if case .empty(let message) = model.assembly {
            DBStateView(kind: .empty, title: "暂无题目", message: message).frame(minHeight: 160)
        }

        Button { startExam() } label: {
            if model.assembly.isLoading {
                HStack(spacing: DBSpacing.sm) { ProgressView().controlSize(.small); Text("正在组卷…") }
                    .frame(maxWidth: .infinity)
            } else {
                Label("开始测验", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.db(.primary, fullWidth: true))
        .disabled(model.assembly.isLoading)
    }

    private func startExam() {
        Task { await model.assemble(using: intelligence) }
        HapticEngine.play(.light)
    }

    // MARK: - Running

    @ViewBuilder
    private var runningPhase: some View {
        // Timer + progress
        HStack {
            Label(model.timeRemainingLabel, systemImage: "timer")
                .font(.dbBodyEmph.monospacedDigit())
                .foregroundStyle(model.isTimeCritical ? Color.dbError : Color.dbPrimary)
                .padding(.horizontal, DBSpacing.md).padding(.vertical, DBSpacing.xs)
                .background(
                    (model.isTimeCritical ? Color.dbErrorSoft : Color.dbPrimarySoft),
                    in: Capsule())
            Spacer()
            Text("第 \(model.currentIndex + 1) / \(model.questions.count) 题")
                .font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
        }

        ProgressView(value: model.progress)
            .tint(.dbPrimary)

        if let q = model.currentQuestion {
            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.md) {
                    HStack { DBSubjectChip(q.subject); Spacer() }
                    if q.subject.isSTEM {
                        MathText(q.prompt, font: .dbTitle3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(q.prompt).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    TextField("在此作答", text: Binding(
                        get: { model.currentAnswer },
                        set: { model.currentAnswer = $0 }), axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(DBSpacing.md)
                        .background(Color.dbBackground, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous).strokeBorder(Color.dbSeparator, lineWidth: 1))
                        #if os(iOS)
                        .submitLabel(.done)
                        #endif
                }
            }
        }

        HStack(spacing: DBSpacing.md) {
            Button { model.goPrevious() } label: {
                Label("上一题", systemImage: "chevron.left").frame(maxWidth: .infinity)
            }
            .buttonStyle(.db(.secondary))
            .disabled(model.isFirstQuestion)

            if model.isLastQuestion {
                Button { model.submit() } label: {
                    Label("交卷", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.db(.primary))
            } else {
                Button { model.goNext() } label: {
                    Label("下一题", systemImage: "chevron.right").frame(maxWidth: .infinity)
                }.buttonStyle(.db(.primary))
            }
        }

        Button { model.submit() } label: {
            Text("提前交卷（已答 \(model.answeredCount)/\(model.questions.count)）")
                .font(.dbFootnote).frame(maxWidth: .infinity)
        }
        .buttonStyle(.db(.ghost))
    }

    // MARK: - Time up

    private var timeUpPhase: some View {
        VStack(spacing: DBSpacing.md) {
            DBMascot(mood: .thinking, size: 72)
            Text("时间到，正在批改…").font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
            ProgressView()
        }
        .frame(maxWidth: .infinity).frame(minHeight: 280)
        .onAppear { model.gradeAfterTimeout() }
    }

    // MARK: - Graded

    @ViewBuilder
    private var gradedPhase: some View {
        DBCard(fill: model.allCorrect ? .dbSuccessSoft : .dbSurface, elevation: .medium) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.lg) {
                    DBProgressRing(progress: model.accuracy, lineWidth: 11,
                                   tint: model.allCorrect ? .dbSuccess : .dbPrimary,
                                   label: "\(model.scorePercent)%")
                        .frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        DBMascot(mood: model.allCorrect ? .cheering : .happy, size: 48)
                        Text(model.didTimeOut ? "时间到 · 已自动交卷" : "测验完成")
                            .font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: DBSpacing.sm) {
                    DBValueStat(value: "\(model.correctCount)", caption: "答对", systemImage: "checkmark.circle.fill", tint: .dbSuccess)
                    DBValueStat(value: "\(model.outcomes.count - model.correctCount)", caption: "答错", systemImage: "xmark.circle.fill", tint: .dbError)
                    DBValueStat(value: "\(model.outcomes.count)", caption: "总题数", systemImage: "number.circle.fill", tint: .dbPrimary)
                }
            }
        }

        DBSectionHeader("逐题回顾", subtitle: "✓ 答对 · ✗ 待订正", systemImage: "list.bullet.clipboard.fill")
        ForEach(Array(model.outcomes.enumerated()), id: \.element.id) { index, outcome in
            recapCard(index: index + 1, outcome: outcome)
        }

        Button { model.reset() } label: {
            Label("再考一次", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
        }
        .buttonStyle(.db(.primary, fullWidth: true))

        Button {
            HapticEngine.play(.light)
            router.navigate(.reports, regular: isRegular)
        } label: {
            Label("查看学习报告", systemImage: "chart.bar.doc.horizontal.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.db(.ghost, fullWidth: true))
        .onAppear { model.persistResults(context: context, existingMasteries: masteries) }
    }

    private func recapCard(index: Int, outcome: ExamOutcome) -> some View {
        DBCard(fill: outcome.isCorrect ? .dbSuccessSoft : .dbErrorSoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack {
                    Label("第 \(index) 题", systemImage: outcome.isCorrect ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(outcome.isCorrect ? Color.dbSuccess : Color.dbError)
                    Spacer()
                    DBSubjectChip(outcome.subject)
                }
                if outcome.subject.isSTEM {
                    MathText(outcome.prompt, font: .dbBody).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(outcome.prompt).font(.dbBody).foregroundStyle(Color.dbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: DBSpacing.md) {
                    answerPill("你的答案", value: outcome.wasAnswered ? outcome.typedAnswer : "未作答",
                               tint: outcome.isCorrect ? .dbSuccess : .dbError)
                    if !outcome.isCorrect {
                        answerPill("正确答案", value: outcome.correctAnswer, tint: .dbSuccess)
                    }
                }
                if !outcome.isCorrect, !outcome.steps.isEmpty {
                    ForEach(outcome.steps) { step in
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(step.index). \(step.title)").font(.dbCaption.weight(.medium)).foregroundStyle(Color.dbTextPrimary)
                            if !step.detail.isEmpty {
                                Text(step.detail).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                            }
                        }
                    }
                }
                if !outcome.isCorrect {
                    Button { model.addToMistakes(outcome, context: context) } label: {
                        Label(model.hasSavedMistake(outcome) ? "已加入错题本" : "加入错题本",
                              systemImage: model.hasSavedMistake(outcome) ? "checkmark" : "book.closed.fill")
                            .font(.dbFootnote.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.hasSavedMistake(outcome) ? Color.dbTextTertiary : Color.dbPrimary)
                    .disabled(model.hasSavedMistake(outcome))
                }
            }
        }
    }

    private func answerPill(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
            Text(value.isEmpty ? "—" : value).font(.dbCallout.weight(.medium)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("模拟测验") {
    NavigationStack { ExamView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
