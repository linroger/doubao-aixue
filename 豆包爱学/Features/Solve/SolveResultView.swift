//
//  SolveResultView.swift
//  豆包爱学 — Features/Solve
//
//  Structured 解析 result for 拍照解题 (RESEARCH §4.1 F6–F8, F12, plus Learn Mode).
//  Pushed by `CaptureSolveView` once a question has been recognized/typed and the
//  learner taps 开始解答. It runs `IntelligenceService.solve(_:)` and renders the
//  canonical solution layout:
//
//      思路 (approach) → 编号步骤 (numbered SolutionStep, math via MathText)
//      → 答案 (boxed) → 知识点 (tappable chips) → for MCQ each ChoiceOption + 解析
//
//  A persistent action row offers 举一反三 (similarProblems sheet), 讲一讲
//  (router → .tutor), 加入错题本 (insert MistakeItem) and 追问 (inline chat).
//  When the learner profile has 学习模式 (anti-cheat) on, the final answer is
//  collapsed behind a "先想想" reveal so the app coaches rather than spoon-feeds.
//
//  Every async surface routes through `ViewState`; the solved problem is persisted
//  as a `ProblemRecord` so it lands in 搜题历史, and 加入错题本 inserts a `MistakeItem`.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

// MARK: - SolveResultView

/// Structured solution screen. Embedded in the navigation stack the shell
/// provides (it does NOT create its own `NavigationStack`).
struct SolveResultView: View {
    let recognizedText: String
    let subject: Subject
    let grade: GradeLevel
    let source: ProblemSource
    let imageData: Data?
    let learnModeEnabled: Bool

    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(TTSService.self) private var tts
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var model: SolveResultModel

    init(recognizedText: String,
         subject: Subject,
         grade: GradeLevel,
         source: ProblemSource = .text,
         imageData: Data? = nil,
         learnModeEnabled: Bool = true) {
        self.recognizedText = recognizedText
        self.subject = subject
        self.grade = grade
        self.source = source
        self.imageData = imageData
        self.learnModeEnabled = learnModeEnabled
        _model = State(initialValue: SolveResultModel(
            recognizedText: recognizedText,
            subject: subject,
            grade: grade,
            source: source,
            imageData: imageData,
            learnModeEnabled: learnModeEnabled))
    }

    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        ScrollView {
            DBStateContainer(model.state, retry: { startSolving() }) { solved in
                solutionBody(solved)
                    .padding(DBSpacing.screenInset)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            // Give the loading/empty/error placeholders breathing room.
            .frame(minHeight: model.state.value == nil ? 460 : nil)
        }
        .background(Color.dbBackground)
        .navigationTitle("解题详情")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if model.state.value != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.toggleNarration(tts: tts)
                    } label: {
                        Label(model.isNarrating ? "停止朗读" : "朗读思路",
                              systemImage: model.isNarrating ? "stop.circle.fill" : "speaker.wave.2.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $model.showSimilarSheet) {
            SimilarProblemsSheet(model: model, intelligence: intelligence)
        }
        .task { startSolvingIfNeeded() }
        .onDisappear { tts.stop() }
    }

    private func startSolvingIfNeeded() {
        guard case .idle = model.state else { return }
        startSolving()
    }

    private func startSolving() {
        Task { await model.solve(using: intelligence, context: modelContext) }
    }

    // MARK: Solution body

    @ViewBuilder
    private func solutionBody(_ solved: SolvedProblem) -> some View {
        VStack(spacing: DBSpacing.lg) {
            questionCard(solved)
            approachCard(solved)
            stepsSection(solved)
            if !solved.choices.isEmpty {
                choicesSection(solved)
            }
            answerCard(solved)
            if !solved.knowledgePoints.isEmpty {
                knowledgePointsSection(solved)
            }
            if model.showFollowUp {
                followUpCard
            }
            actionRow(solved)
                .padding(.top, DBSpacing.xs)
        }
    }

    // MARK: Recognized question + route badge

    private func questionCard(_ solved: SolvedProblem) -> some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.sm) {
                    DBSubjectChip(solved.subject)
                    Label(source.displayName, systemImage: source.symbolName)
                        .font(.dbCaption.weight(.medium))
                        .foregroundStyle(Color.dbTextSecondary)
                    Spacer(minLength: 0)
                    DBRouteBadge(solved.route)
                }
                MathText(model.recognizedText, font: .dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: 思路 (approach)

    private func approachCard(_ solved: SolvedProblem) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("解题思路", systemImage: "lightbulb.fill")
                Text(solved.approach)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: 步骤 (numbered solution steps)

    private func stepsSection(_ solved: SolvedProblem) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("详细步骤", subtitle: "共 \(solved.steps.count) 步", systemImage: "list.number")
            VStack(spacing: DBSpacing.sm) {
                ForEach(solved.steps) { step in
                    SolveStepRow(step: step)
                }
            }
        }
    }

    // MARK: MCQ choices (each option + explanation)

    private func choicesSection(_ solved: SolvedProblem) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("选项解析", subtitle: "理解每个选项为什么对或错", systemImage: "checklist")
            VStack(spacing: DBSpacing.sm) {
                ForEach(solved.choices) { choice in
                    ChoiceOptionRow(choice: choice, revealed: model.answerRevealed)
                }
            }
        }
    }

    // MARK: 答案 (boxed, gated behind 先想想 in Learn Mode)

    @ViewBuilder
    private func answerCard(_ solved: SolvedProblem) -> some View {
        DBCard(fill: .dbSecondarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.sm) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.dbSecondary)
                    Text("最终答案").font(.dbHeadline).foregroundStyle(Color.dbTextPrimary)
                    Spacer(minLength: 0)
                    if model.isLearnMode {
                        DBTag("学习模式", tint: .dbSecondary)
                    }
                }

                if model.answerRevealed {
                    MathText(solved.finalAnswer, font: .dbTitle3)
                        .foregroundStyle(Color.dbSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Button {
                        model.revealAnswer()
                    } label: {
                        HStack(spacing: DBSpacing.sm) {
                            Image(systemName: "eye.fill")
                            Text("先想想，再看答案")
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.dbFootnote)
                        }
                    }
                    .buttonStyle(.db(.secondary, fullWidth: true))
                    Text("学习模式下先尝试思考，能记得更牢。想好了再点开核对。")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                }
            }
            .animation(.spring(duration: 0.3), value: model.answerRevealed)
        }
    }

    // MARK: 知识点 chips

    private func knowledgePointsSection(_ solved: SolvedProblem) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("相关知识点", systemImage: "point.3.connected.trianglepath.dotted")
            DBFlowLayout(spacing: DBSpacing.sm) {
                ForEach(solved.knowledgePoints) { kp in
                    Button {
                        router.navigate(.knowledgePoint(kp.id), regular: isRegular)
                    } label: {
                        DBChip(kp.name, systemImage: "graduationcap.fill",
                               tint: DBSubjectColor.color(for: kp.subject))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: 追问 (inline follow-up)

    private var followUpCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("继续追问", subtitle: "没听懂哪一步？再问问豆包", systemImage: "bubble.left.and.text.bubble.right.fill")

                ForEach(model.followUps) { turn in
                    SolveFollowUpBubble(turn: turn)
                }

                if model.isFollowingUp {
                    HStack(spacing: DBSpacing.sm) {
                        ProgressView().controlSize(.small).tint(Color.dbPrimary)
                        Text("豆包正在思考…").font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                    }
                }

                HStack(spacing: DBSpacing.sm) {
                    TextField("例如：第 2 步为什么这样算？", text: $model.followUpDraft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.dbBody)
                        .lineLimit(1...3)
                        .padding(.horizontal, DBSpacing.md)
                        .padding(.vertical, DBSpacing.sm)
                        .background(Color.dbBackgroundAlt, in: Capsule())
                        .submitLabel(.send)
                        .onSubmit { sendFollowUp() }
                    Button {
                        sendFollowUp()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(model.canSendFollowUp ? Color.dbPrimary : Color.dbTextTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canSendFollowUp)
                }

                if model.followUps.isEmpty {
                    suggestedQuestions
                }
            }
        }
    }

    private var suggestedQuestions: some View {
        DBFlowLayout(spacing: DBSpacing.sm) {
            ForEach(model.suggestedFollowUps, id: \.self) { q in
                Button {
                    model.followUpDraft = q
                    sendFollowUp()
                } label: {
                    DBChip(q, systemImage: "sparkles", tint: .dbInfo)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sendFollowUp() {
        guard model.canSendFollowUp else { return }
        Task { await model.sendFollowUp(using: intelligence) }
    }

    // MARK: Action row (举一反三 | 讲一讲 | 加入错题本 | 追问)

    private func actionRow(_ solved: SolvedProblem) -> some View {
        VStack(spacing: DBSpacing.sm) {
            HStack(spacing: DBSpacing.sm) {
                SolveActionButton(title: "举一反三", systemImage: "square.grid.3x3.fill", tint: .dbPrimary) {
                    model.showSimilarSheet = true
                    HapticEngine.play(.light)
                }
                SolveActionButton(title: "讲一讲", systemImage: "person.wave.2.fill", tint: .dbSecondary) {
                    router.present(.tutor(problemText: model.recognizedText,
                                          subject: solved.subject,
                                          grade: grade))
                    HapticEngine.play(.light)
                }
            }
            HStack(spacing: DBSpacing.sm) {
                SolveActionButton(
                    title: model.savedToMistakes ? "已在错题本" : "加入错题本",
                    systemImage: model.savedToMistakes ? "checkmark.seal.fill" : "book.closed.fill",
                    tint: model.savedToMistakes ? .dbSuccess : .dbAccent,
                    isHighlighted: model.savedToMistakes
                ) {
                    model.addToMistakes(context: modelContext)
                }
                .disabled(model.savedToMistakes)

                SolveActionButton(
                    title: model.showFollowUp ? "收起追问" : "追问",
                    systemImage: "bubble.left.and.text.bubble.right.fill",
                    tint: .dbInfo
                ) {
                    model.toggleFollowUp()
                    HapticEngine.play(.selection)
                }
            }
            SolveActionButton(
                title: model.savedToBank ? "已加入题库" : "收藏到题库",
                systemImage: model.savedToBank ? "checkmark.seal.fill" : "tray.full.fill",
                tint: model.savedToBank ? .dbSuccess : .dbPrimary,
                isHighlighted: model.savedToBank
            ) {
                model.addToBank(context: modelContext)
            }
            .disabled(model.savedToBank)
        }
    }
}

// MARK: - Step row

private struct SolveStepRow: View {
    let step: SolutionStep

    var body: some View {
        DBCard {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                Text("\(step.index)")
                    .font(.dbBodyEmph.monospacedDigit())
                    .foregroundStyle(Color.dbOnPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.dbPrimary, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text(step.title)
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    if !step.detail.isEmpty {
                        Text(step.detail)
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let math = step.math, !math.isEmpty {
                        MathText(math, font: .dbMonoBody)
                            .foregroundStyle(Color.dbTextPrimary)
                            .padding(.horizontal, DBSpacing.md)
                            .padding(.vertical, DBSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.dbBackgroundAlt,
                                        in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                            .textSelection(.enabled)
                    }
                    if let figure = step.figure {
                        FigureView(figure: figure)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(step.index) 步，\(step.title)。\(step.detail)")
    }
}

// MARK: - Figure stand-in (SF Symbol + caption)

private struct FigureView: View {
    let figure: FigureRef

    var body: some View {
        HStack(spacing: DBSpacing.sm) {
            Image(systemName: figure.systemSymbol)
                .font(.system(size: 26))
                .foregroundStyle(Color.dbSecondary)
                .frame(width: 48, height: 48)
                .background(Color.dbSecondarySoft, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
            Text(figure.caption)
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DBSpacing.sm)
        .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
        .accessibilityLabel("图示：\(figure.caption)")
    }
}

// MARK: - Choice option row (MCQ)

private struct ChoiceOptionRow: View {
    let choice: ChoiceOption
    /// When the answer is still hidden (Learn Mode), we don't reveal which option
    /// is correct, only the per-option reasoning.
    let revealed: Bool

    private var showCorrectness: Bool { revealed && choice.isCorrect }

    var body: some View {
        DBCard(fill: showCorrectness ? .dbSuccessSoft : .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                HStack(spacing: DBSpacing.sm) {
                    Text(choice.label)
                        .font(.dbBodyEmph)
                        .foregroundStyle(showCorrectness ? Color.dbOnPrimary : Color.dbPrimary)
                        .frame(width: 26, height: 26)
                        .background(showCorrectness ? AnyShapeStyle(Color.dbSuccess)
                                                    : AnyShapeStyle(Color.dbPrimarySoft),
                                    in: Circle())
                    MathText(choice.text, font: .dbBody)
                        .foregroundStyle(Color.dbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showCorrectness {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.dbSuccess)
                    }
                }
                if !choice.explanation.isEmpty {
                    Text(choice.explanation)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 26 + DBSpacing.sm)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("选项 \(choice.label)，\(choice.text)。\(showCorrectness ? "正确答案。" : "")\(choice.explanation)")
    }
}

// MARK: - Action button

private struct SolveActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isHighlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DBSpacing.sm) {
                Image(systemName: systemImage)
                Text(title).font(.dbCallout.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DBSpacing.md)
            .foregroundStyle(isHighlighted ? Color.dbOnPrimary : tint)
            .background(isHighlighted ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)),
                        in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Follow-up bubble

private struct SolveFollowUpBubble: View {
    let turn: SolveFollowUpTurn

    var body: some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            if turn.isUser { Spacer(minLength: DBSpacing.xl) }
            VStack(alignment: turn.isUser ? .trailing : .leading, spacing: 2) {
                Text(turn.isUser ? "我" : "豆包")
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextTertiary)
                Text(turn.text)
                    .font(.dbCallout)
                    .foregroundStyle(turn.isUser ? Color.dbOnPrimary : Color.dbTextPrimary)
                    .padding(.horizontal, DBSpacing.md)
                    .padding(.vertical, DBSpacing.sm)
                    .background(
                        turn.isUser ? AnyShapeStyle(Color.dbPrimary) : AnyShapeStyle(Color.dbBackgroundAlt),
                        in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                    )
                    .frame(maxWidth: .infinity, alignment: turn.isUser ? .trailing : .leading)
                    .textSelection(.enabled)
            }
            if !turn.isUser { Spacer(minLength: DBSpacing.xl) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(turn.isUser ? "我问" : "豆包答")：\(turn.text)")
    }
}

// MARK: - Similar problems sheet (举一反三)

private struct SimilarProblemsSheet: View {
    @Bindable var model: SolveResultModel
    let intelligence: any IntelligenceService

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                DBStateContainer(model.similarState, retry: { reload() }) { problems in
                    VStack(spacing: DBSpacing.md) {
                        DBCard(fill: .dbPrimarySoft, elevation: .none) {
                            HStack(spacing: DBSpacing.md) {
                                DBMascot(mood: .cheering, size: 48)
                                Text("会做这一道，还要会做这一类。试试这些同类题吧！")
                                    .font(.dbCallout)
                                    .foregroundStyle(Color.dbTextPrimary)
                                Spacer(minLength: 0)
                            }
                        }
                        ForEach(Array(problems.enumerated()), id: \.element.id) { index, problem in
                            SimilarProblemCard(index: index + 1, problem: problem,
                                               isRevealed: model.revealedSimilarIDs.contains(problem.id)) {
                                model.revealSimilar(problem.id)
                            }
                        }
                    }
                    .padding(DBSpacing.screenInset)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: model.similarState.value == nil ? 420 : nil)
            }
            .background(Color.dbBackground)
            .navigationTitle("举一反三")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { loadIfNeeded() }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    private func loadIfNeeded() {
        guard case .idle = model.similarState else { return }
        reload()
    }

    private func reload() {
        Task { await model.loadSimilar(using: intelligence) }
    }
}

private struct SimilarProblemCard: View {
    let index: Int
    let problem: GeneratedProblem
    let isRevealed: Bool
    let onReveal: () -> Void

    private var difficultyStars: String {
        let n = max(1, min(5, problem.difficulty))
        return String(repeating: "★", count: n) + String(repeating: "☆", count: 5 - n)
    }

    var body: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack {
                    Text("第 \(index) 题")
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(Color.dbPrimary)
                    Spacer()
                    Text(difficultyStars)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbAccent)
                        .accessibilityLabel("难度 \(problem.difficulty) 星")
                }
                MathText(problem.question, font: .dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if isRevealed {
                    Divider().overlay(Color.dbSeparator)
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Label("参考答案", systemImage: "checkmark.seal.fill")
                            .font(.dbFootnote.weight(.medium))
                            .foregroundStyle(Color.dbSecondary)
                        MathText(problem.answer, font: .dbBodyEmph)
                            .foregroundStyle(Color.dbSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(problem.steps) { step in
                            HStack(alignment: .top, spacing: DBSpacing.xs) {
                                Text("\(step.index).").font(.dbCaption.monospacedDigit())
                                    .foregroundStyle(Color.dbTextTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(step.title).font(.dbCaption.weight(.medium))
                                        .foregroundStyle(Color.dbTextPrimary)
                                    if !step.detail.isEmpty {
                                        Text(step.detail).font(.dbCaption)
                                            .foregroundStyle(Color.dbTextSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                } else {
                    Button("先做做看，再看答案") { onReveal() }
                        .buttonStyle(.db(.ghost, fullWidth: true))
                }
            }
            .animation(.spring(duration: 0.3), value: isRevealed)
        }
    }
}

// MARK: - Follow-up turn value type

nonisolated struct SolveFollowUpTurn: Identifiable, Sendable, Hashable {
    let id = UUID()
    let isUser: Bool
    var text: String
}

// MARK: - View model

@MainActor
@Observable
final class SolveResultModel {
    let recognizedTextInput: String
    let subject: Subject
    let grade: GradeLevel
    let source: ProblemSource
    let imageData: Data?
    let learnModeEnabled: Bool

    /// The (possibly edited) question text we display and persist.
    private(set) var recognizedText: String

    // Core solve state.
    private(set) var state: ViewState<SolvedProblem> = .idle

    // Learn Mode answer gating.
    private(set) var answerRevealed: Bool

    // Persistence flags.
    private(set) var savedToMistakes = false
    private var savedRecordID: UUID?

    // Narration.
    var isNarrating = false

    // 举一反三.
    var showSimilarSheet = false
    private(set) var similarState: ViewState<[GeneratedProblem]> = .idle
    private(set) var revealedSimilarIDs: Set<String> = []

    // 追问.
    private(set) var showFollowUp = false
    var followUpDraft: String = ""
    private(set) var followUps: [SolveFollowUpTurn] = []
    private(set) var isFollowingUp = false

    init(recognizedText: String,
         subject: Subject,
         grade: GradeLevel,
         source: ProblemSource,
         imageData: Data?,
         learnModeEnabled: Bool) {
        self.recognizedTextInput = recognizedText
        self.recognizedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subject = subject
        self.grade = grade
        self.source = source
        self.imageData = imageData
        self.learnModeEnabled = learnModeEnabled
        // Answer starts hidden only when Learn Mode is on.
        self.answerRevealed = !learnModeEnabled
    }

    var isLearnMode: Bool { learnModeEnabled }

    var suggestedFollowUps: [String] {
        ["这道题的关键是什么？", "可以换个方法解吗？", "哪一步最容易出错？"]
    }

    var canSendFollowUp: Bool {
        !followUpDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isFollowingUp
    }

    // MARK: Solve

    func solve(using intelligence: any IntelligenceService, context: ModelContext) async {
        let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .empty(message: "题目内容为空，请返回重新拍照或输入。")
            return
        }
        state = .loading
        let request = SolveRequest(recognizedText: trimmed, subject: subject,
                                   grade: grade, mode: .solve, learnMode: learnModeEnabled,
                                   imageData: imageData)
        do {
            let solved = try await intelligence.solve(request)
            recognizedText = trimmed
            state = .loaded(solved)
            persist(solved, context: context)
            HapticEngine.play(.success)
        } catch IntelligenceError.emptyInput {
            state = .empty(message: "题目内容为空，请返回重新拍照或输入。")
        } catch {
            state = .error(message: "解答没有完成，请检查网络或稍后再试一次。")
            HapticEngine.play(.error)
        }
    }

    // MARK: Learn Mode reveal

    func revealAnswer() {
        guard !answerRevealed else { return }
        answerRevealed = true
        HapticEngine.play(.light)
    }

    // MARK: Narration (TTS of approach + steps)

    func toggleNarration(tts: TTSService) {
        if isNarrating {
            tts.stop()
            isNarrating = false
            return
        }
        guard case let .loaded(solved) = state else { return }
        var script = "解题思路。\(solved.approach)。"
        for step in solved.steps {
            script += "第\(step.index)步，\(step.title)。\(step.detail)。"
        }
        if answerRevealed {
            script += "最终答案是，\(MathText.spokenLabel(from: solved.finalAnswer))。"
        }
        tts.speak(script, language: solved.subject == .english ? "en-US" : "zh-CN")
        isNarrating = true
    }

    // MARK: Persistence — ProblemRecord (搜题历史)

    private func persist(_ solved: SolvedProblem, context: ModelContext) {
        let record: ProblemRecord
        if let id = savedRecordID,
           let existing = try? context.fetch(
            FetchDescriptor<ProblemRecord>(predicate: #Predicate { $0.id == id })
           ).first {
            record = existing
        } else {
            record = ProblemRecord()
            context.insert(record)
            savedRecordID = record.id
        }
        record.subject = solved.subject
        record.source = source
        record.recognizedText = recognizedText
        record.imageData = imageData
        record.steps = solved.steps
        record.choices = solved.choices
        record.finalAnswer = solved.finalAnswer
        record.approach = solved.approach
        record.knowledgePoints = solved.knowledgePoints
        record.route = solved.route
        record.savedToMistakes = savedToMistakes
        record.createdAt = Date()
        context.saveLogging()
    }

    // MARK: 加入错题本 — MistakeItem

    func addToMistakes(context: ModelContext) {
        guard !savedToMistakes, case let .loaded(solved) = state else { return }

        let item = MistakeItem()
        item.subject = solved.subject
        item.questionText = recognizedText
        item.imageData = imageData
        item.correctAnswer = solved.finalAnswer
        item.errorReason = "拍照解题后主动收藏，建议二次复习巩固。"
        item.errorType = .knowledgeGap
        item.mastery = .new
        item.knowledgePointIDs = solved.knowledgePoints.map(\.id)
        item.steps = solved.steps
        item.reviewCount = 0
        item.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        item.createdAt = Date()
        context.insert(item)

        // Keep the linked ProblemRecord flag in sync.
        if let id = savedRecordID,
           let record = try? context.fetch(
            FetchDescriptor<ProblemRecord>(predicate: #Predicate { $0.id == id })
           ).first {
            record.savedToMistakes = true
        }
        // Only reflect success in the UI once the write actually persisted, so the
        // "已在错题本" state can't diverge from the database on a failed save.
        if context.saveLogging() {
            savedToMistakes = true
            HapticEngine.play(.success)
        } else {
            HapticEngine.play(.error)
        }
    }

    // MARK: 收藏到题库 — BankedQuestion

    private(set) var savedToBank = false

    func addToBank(context: ModelContext) {
        guard !savedToBank, case let .loaded(solved) = state else { return }
        let item = BankedQuestion()
        item.subject = solved.subject
        item.type = solved.choices.isEmpty ? .other : .multipleChoice
        item.questionText = recognizedText
        item.imageData = imageData
        item.correctAnswer = solved.finalAnswer
        item.explanation = solved.approach
        item.setKnowledgePoints(solved.knowledgePoints)
        item.steps = solved.steps
        item.source = .solve
        item.mastery = .new
        item.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        context.insert(item)
        if context.saveLogging() {
            savedToBank = true
            HapticEngine.play(.success)
        } else {
            HapticEngine.play(.error)
        }
    }

    // MARK: 举一反三

    func loadSimilar(using intelligence: any IntelligenceService) async {
        guard case let .loaded(solved) = state else {
            similarState = .empty(message: "请先完成本题解答，再生成同类题。")
            return
        }
        similarState = .loading
        let request = SimilarRequest(subject: solved.subject,
                                     knowledgePoints: solved.knowledgePoints,
                                     referenceText: recognizedText,
                                     count: 3, grade: grade)
        do {
            let problems = try await intelligence.similarProblems(request)
            if problems.isEmpty {
                similarState = .empty(message: "暂时没有生成同类题，换一道题再试试吧。")
            } else {
                similarState = .loaded(problems)
            }
        } catch {
            similarState = .error(message: "同类题没有生成成功，请稍后再试。")
        }
    }

    func revealSimilar(_ id: String) {
        revealedSimilarIDs.insert(id)
        HapticEngine.play(.light)
    }

    // MARK: 追问

    func toggleFollowUp() {
        showFollowUp.toggle()
    }

    func sendFollowUp(using intelligence: any IntelligenceService) async {
        let question = followUpDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isFollowingUp else { return }
        followUps.append(SolveFollowUpTurn(isUser: true, text: question))
        followUpDraft = ""
        isFollowingUp = true

        // Build a chat request that carries the problem context so the reply is grounded.
        var turns: [ChatTurn] = [
            ChatTurn(role: .user, text: "题目：\(recognizedText)"),
            ChatTurn(role: .user, text: question),
        ]
        if let solved = state.value {
            turns.insert(ChatTurn(role: .assistant, text: "解题思路：\(solved.approach)"), at: 1)
        }
        let context = LearnerContext(grade: grade, subjects: [subject], learnModeEnabled: learnModeEnabled)
        let request = ChatRequest(turns: turns, context: context, kind: .tutor)

        var reply = ""
        let placeholder = SolveFollowUpTurn(isUser: false, text: "")
        followUps.append(placeholder)
        let replyIndex = followUps.count - 1

        do {
            for try await chunk in intelligence.chat(request) {
                reply += chunk.delta
                if !reply.isEmpty {
                    followUps[replyIndex].text = reply
                }
            }
            if followUps[replyIndex].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                followUps[replyIndex].text = "我们一步步来：先回到题目条件，看看每一步用到的依据。你具体卡在哪一步呢？"
            }
            HapticEngine.play(.light)
        } catch {
            followUps[replyIndex].text = "刚才没接上，请再问一次。"
        }
        isFollowingUp = false
    }
}

// MARK: - Preview

#Preview("解题详情 · 学习模式") {
    NavigationStack {
        SolveResultView(
            recognizedText: "一个长方形长 8 厘米，宽 5 厘米，面积是多少？",
            subject: .math,
            grade: .g5,
            source: .text,
            imageData: nil,
            learnModeEnabled: true)
    }
    .environment(AppRouter())
    .environment(TTSService())
    .modelContainer(for: [LearnerProfile.self, ProblemRecord.self, MistakeItem.self], inMemory: true)
}

#Preview("解题详情 · 选择题") {
    NavigationStack {
        SolveResultView(
            recognizedText: "Choose: She ___ to school every day. A. go B. goes C. going",
            subject: .english,
            grade: .g7,
            source: .text,
            imageData: nil,
            learnModeEnabled: false)
    }
    .environment(AppRouter())
    .environment(TTSService())
    .modelContainer(for: [LearnerProfile.self, ProblemRecord.self, MistakeItem.self], inMemory: true)
}
