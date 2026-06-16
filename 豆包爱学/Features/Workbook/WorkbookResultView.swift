//
//  WorkbookResultView.swift
//  豆包爱学 — Features/Workbook
//
//  Renders a `GradedWorkbook` — the structured 作业批改 result — into a warm, scannable
//  layout that works for any subject: a score summary header, an overall comment, the
//  original photo, then one card per question with a ✓/✗/◐ verdict, the student's answer
//  vs. the correct answer, a teaching explanation, knowledge-point chips, optional worked
//  steps and (for subjective questions) a rubric. Every wrong question can be saved to the
//  错题本 or 题库, asked about (讲一讲 → tutor), or extended (举一反三).
//
//  `WorkbookResultContent` is shared by the live grading screen and 批改历史 (re-rendered
//  from the persisted `GradedWorkbook`), so a past grading looks identical to a fresh one.
//

import SwiftUI
import SwiftData

// MARK: - Result content (shared)

struct WorkbookResultContent: View {
    let workbook: GradedWorkbook
    let imageData: Data?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(TTSService.self) private var tts
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var savedToMistakes: Set<String> = []
    @State private var savedToBank: Set<String> = []
    @State private var bulkMistakesDone = false
    @State private var bulkBankDone = false
    @State private var showFullImage = false

    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        VStack(spacing: DBSpacing.lg) {
            summaryCard
            if !workbook.overallComment.isEmpty || !workbook.encouragement.isEmpty {
                overallCard
            }
            if imageData != nil {
                originalImageCard
            }
            if !workbook.wrongQuestions.isEmpty {
                bulkActionsCard
            }
            questionsSection
        }
        .sheet(isPresented: $showFullImage) { fullImageSheet }
        .onChange(of: workbook) { _, _ in
            // A fresh grading (re-photograph / re-grade) → clear the per-result save
            // state so "已收录 / 已入库" never lingers onto different questions.
            savedToMistakes = []
            savedToBank = []
            bulkMistakesDone = false
            bulkBankDone = false
        }
    }

    // MARK: Summary header

    private var summaryCard: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.md) {
                    DBProgressRing(progress: workbook.accuracy,
                                   tint: accuracyTint,
                                   label: "\(workbook.correctCount)/\(workbook.total)")
                        .frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text(workbook.title)
                            .font(.dbHeadline)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(2)
                        HStack(spacing: DBSpacing.sm) {
                            ForEach(workbook.detectedSubjects, id: \.self) { DBSubjectChip($0) }
                            DBRouteBadge(workbook.route)
                        }
                        if workbook.isScored {
                            Text("得分 \(Self.num(workbook.scoreEarned)) / \(Self.num(workbook.scorePossible))")
                                .font(.dbFootnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Color.dbTextSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                tallyRow
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("批改结果，共 \(workbook.total) 题，做对 \(workbook.correctCount) 题")
    }

    private var tallyRow: some View {
        HStack(spacing: DBSpacing.sm) {
            tally("正确", workbook.correctCount, tint: .dbSuccess, symbol: "checkmark.circle.fill")
            if workbook.partialCount > 0 {
                tally("部分", workbook.partialCount, tint: .dbWarning, symbol: "circle.lefthalf.filled")
            }
            tally("错误", workbook.incorrectCount, tint: .dbError, symbol: "xmark.circle.fill")
            if workbook.unattemptedCount > 0 {
                tally("未答", workbook.unattemptedCount, tint: .dbTextTertiary, symbol: "circle.dashed")
            }
        }
    }

    private func tally(_ label: String, _ count: Int, tint: Color, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.dbFootnote).foregroundStyle(tint)
            Text("\(label) \(count)").font(.dbFootnote.weight(.medium).monospacedDigit())
                .foregroundStyle(Color.dbTextSecondary)
        }
        .padding(.horizontal, DBSpacing.sm)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: Overall comment

    private var overallCard: some View {
        DBCard {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                DBMascot(mood: workbook.accuracy >= 0.8 ? .cheering : .happy, size: 52)
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    if !workbook.overallComment.isEmpty {
                        Text(workbook.overallComment)
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !workbook.encouragement.isEmpty {
                        Text(workbook.encouragement)
                            .font(.dbFootnote.weight(.medium))
                            .foregroundStyle(Color.dbPrimaryDeep)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Original photo

    private var originalImageCard: some View {
        Button { showFullImage = true } label: {
            ZStack(alignment: .bottomTrailing) {
                if let image = imageData.flatMap({ Image.fromWorkbookData($0) }) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
                }
                Label("查看原图", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.dbCaption2.weight(.semibold))
                    .padding(.horizontal, DBSpacing.sm).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(DBSpacing.sm)
            }
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous).strokeBorder(Color.dbSeparator, lineWidth: 1))
    }

    private var fullImageSheet: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                if let image = imageData.flatMap({ Image.fromWorkbookData($0) }) {
                    image.resizable().scaledToFit()
                }
            }
            .background(Color.dbBackground)
            .navigationTitle("作业原图")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showFullImage = false }
                }
            }
        }
    }

    // MARK: Bulk actions

    private var bulkActionsCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Label("\(workbook.wrongQuestions.count) 道错题，建议收录后复习", systemImage: "tray.and.arrow.down.fill")
                    .font(.dbCallout.weight(.medium))
                    .foregroundStyle(Color.dbTextPrimary)
                HStack(spacing: DBSpacing.sm) {
                    Button {
                        saveAllWrong(toBank: false)
                    } label: {
                        Label(bulkMistakesDone ? "已存入错题本" : "全部存入错题本",
                              systemImage: bulkMistakesDone ? "checkmark.seal.fill" : "book.closed.fill")
                            .font(.dbFootnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.db(bulkMistakesDone ? .ghost : .secondary, fullWidth: true))
                    .disabled(bulkMistakesDone)

                    Button {
                        saveAllWrong(toBank: true)
                    } label: {
                        Label(bulkBankDone ? "已加入题库" : "全部加入题库",
                              systemImage: bulkBankDone ? "checkmark.seal.fill" : "tray.full.fill")
                            .font(.dbFootnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.db(bulkBankDone ? .ghost : .secondary, fullWidth: true))
                    .disabled(bulkBankDone)
                }
            }
        }
    }

    // MARK: Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("逐题批改", subtitle: "共 \(workbook.total) 题", systemImage: "list.bullet.rectangle.portrait.fill")
            ForEach(workbook.questions) { q in
                questionCard(q)
            }
        }
    }

    private func questionCard(_ q: GradedQuestion) -> some View {
        DBCard(fill: cardFill(q.verdict), elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                // Header: number + verdict + type/subject
                HStack(spacing: DBSpacing.sm) {
                    Text(q.number)
                        .font(.dbFootnote.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.dbOnPrimary)
                        .frame(minWidth: 26, minHeight: 26)
                        .padding(.horizontal, 4)
                        .background(verdictTint(q.verdict), in: Capsule())
                    Image(systemName: q.verdict.symbolName)
                        .foregroundStyle(verdictTint(q.verdict))
                    Text(q.verdict.displayName)
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(verdictTint(q.verdict))
                    Spacer(minLength: 0)
                    DBTag(q.type.displayName, tint: .dbInfo)
                    DBSubjectChip(q.subject)
                }

                // Question text
                if !q.questionText.isEmpty {
                    if q.isMathy {
                        MathText(q.questionText, font: .dbBody)
                            .foregroundStyle(Color.dbTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Text(q.questionText)
                            .font(.dbBody)
                            .foregroundStyle(Color.dbTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                // Answers
                answerRows(q)

                // Points
                if let possible = q.pointsPossible {
                    Text("得分 \(Self.num(q.pointsEarned ?? 0)) / \(Self.num(possible))")
                        .font(.dbCaption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.dbTextSecondary)
                }

                // Explanation
                if !q.explanation.isEmpty {
                    explanationBlock(q)
                }

                // Worked steps
                if !q.steps.isEmpty {
                    stepsBlock(q)
                }

                // Rubric (subjective)
                if !q.rubric.isEmpty {
                    rubricBlock(q)
                }

                // Teacher comment
                if let note = q.teacherComment, !note.isEmpty {
                    Label(note, systemImage: "quote.bubble.fill")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Knowledge points
                if !q.knowledgePoints.isEmpty {
                    DBFlowLayout(spacing: DBSpacing.xs) {
                        ForEach(q.knowledgePoints) { kp in
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

                // Error type tag
                if let err = q.errorType {
                    DBTag("错因 · \(err.displayName)", tint: .dbError)
                }

                // Per-question actions (only worth offering on wrong/partial questions)
                if q.isWrong {
                    questionActions(q)
                }
            }
        }
    }

    private func answerRows(_ q: GradedQuestion) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            if !q.studentAnswer.isEmpty {
                answerRow(label: "我的答案", value: q.studentAnswer,
                          tint: q.verdict == .correct ? .dbSuccess : .dbError, mathy: q.isMathy)
            }
            if !q.correctAnswer.isEmpty && q.verdict != .correct {
                answerRow(label: "正确答案", value: q.correctAnswer, tint: .dbSuccess, mathy: q.isMathy)
            }
        }
    }

    private func answerRow(label: String, value: String, tint: Color, mathy: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DBSpacing.sm) {
            Text(label)
                .font(.dbCaption.weight(.medium))
                .foregroundStyle(Color.dbTextTertiary)
                .frame(width: 64, alignment: .leading)
            if mathy {
                MathText(value, font: .dbCallout.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.dbCallout.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, DBSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
    }

    private func explanationBlock(_ q: GradedQuestion) -> some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: "lightbulb.fill").font(.dbFootnote).foregroundStyle(Color.dbAccent)
            Text(q.explanation)
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DBSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbAccentSoft, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
    }

    private func stepsBlock(_ q: GradedQuestion) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            ForEach(q.steps) { step in
                HStack(alignment: .top, spacing: DBSpacing.xs) {
                    Text("\(step.index).").font(.dbCaption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.dbPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.dbCaption.weight(.medium)).foregroundStyle(Color.dbTextPrimary)
                        if !step.detail.isEmpty {
                            Text(step.detail).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                        }
                        if let math = step.math, !math.isEmpty {
                            MathText(math, font: .dbMonoBody).foregroundStyle(Color.dbTextPrimary)
                        }
                    }
                }
            }
        }
        .padding(.leading, DBSpacing.xs)
    }

    private func rubricBlock(_ q: GradedQuestion) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            ForEach(q.rubric) { dim in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(dim.name).font(.dbCaption.weight(.medium)).foregroundStyle(Color.dbTextPrimary)
                        Spacer()
                        Text("\(Self.num(dim.score))/\(Self.num(dim.maxScore))")
                            .font(.dbCaption.monospacedDigit()).foregroundStyle(Color.dbTextSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.dbSeparator)
                            Capsule().fill(Color.dbSecondary)
                                .frame(width: max(6, geo.size.width * (dim.maxScore == 0 ? 0 : dim.score / dim.maxScore)))
                        }
                    }
                    .frame(height: 6)
                    if !dim.comment.isEmpty {
                        Text(dim.comment).font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
                    }
                }
            }
        }
    }

    private func questionActions(_ q: GradedQuestion) -> some View {
        HStack(spacing: DBSpacing.sm) {
            compactAction(savedToMistakes.contains(q.id) ? "已收录" : "错题本",
                          systemImage: savedToMistakes.contains(q.id) ? "checkmark" : "book.closed.fill",
                          tint: .dbAccent, done: savedToMistakes.contains(q.id)) {
                saveToMistakes(q)
            }
            compactAction(savedToBank.contains(q.id) ? "已入库" : "题库",
                          systemImage: savedToBank.contains(q.id) ? "checkmark" : "tray.full.fill",
                          tint: .dbPrimary, done: savedToBank.contains(q.id)) {
                saveToBank(q)
            }
            compactAction("讲一讲", systemImage: "person.wave.2.fill", tint: .dbSecondary, done: false) {
                router.present(.tutor(problemText: tutorPrompt(q), subject: q.subject, grade: workbook.grade))
                HapticEngine.play(.light)
            }
        }
        .padding(.top, 2)
    }

    private func compactAction(_ title: String, systemImage: String, tint: Color, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.dbCaption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DBSpacing.sm)
                .foregroundStyle(done ? Color.dbTextTertiary : tint)
                .background(tint.opacity(done ? 0.06 : 0.14), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(done && title.hasPrefix("已"))
    }

    // MARK: Saving

    private func saveToMistakes(_ q: GradedQuestion) {
        guard !savedToMistakes.contains(q.id) else { return }
        let item = Self.makeMistake(from: q, imageData: imageData)
        modelContext.insert(item)
        if modelContext.saveLogging() {
            savedToMistakes.insert(q.id)
            HapticEngine.play(.success)
        }
    }

    private func saveToBank(_ q: GradedQuestion) {
        guard !savedToBank.contains(q.id) else { return }
        let item = BankedQuestion.make(from: q, source: .workbook, imageData: imageData)
        modelContext.insert(item)
        if modelContext.saveLogging() {
            savedToBank.insert(q.id)
            HapticEngine.play(.success)
        }
    }

    private func saveAllWrong(toBank: Bool) {
        for q in workbook.wrongQuestions {
            if toBank {
                guard !savedToBank.contains(q.id) else { continue }
                modelContext.insert(BankedQuestion.make(from: q, source: .workbook, imageData: imageData))
                savedToBank.insert(q.id)
            } else {
                guard !savedToMistakes.contains(q.id) else { continue }
                modelContext.insert(Self.makeMistake(from: q, imageData: imageData))
                savedToMistakes.insert(q.id)
            }
        }
        if modelContext.saveLogging() {
            if toBank { bulkBankDone = true } else { bulkMistakesDone = true }
            HapticEngine.play(.success)
        }
    }

    static func makeMistake(from q: GradedQuestion, imageData: Data?) -> MistakeItem {
        let item = MistakeItem()
        item.subject = q.subject
        item.questionText = q.questionText
        item.imageData = imageData
        item.studentAnswer = q.studentAnswer
        item.correctAnswer = q.correctAnswer
        item.errorReason = q.explanation.isEmpty ? "作业批改收录，建议二次复习巩固。" : q.explanation
        item.errorType = q.errorType ?? .knowledgeGap
        item.mastery = .new
        item.knowledgePointIDs = q.knowledgePoints.map(\.id)
        item.steps = q.steps
        item.reviewCount = 0
        item.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        item.createdAt = Date()
        return item
    }

    private func tutorPrompt(_ q: GradedQuestion) -> String {
        var p = "请给我讲讲这道题：\(q.questionText)"
        if !q.studentAnswer.isEmpty { p += "\n我的答案是：\(q.studentAnswer)，" }
        if !q.correctAnswer.isEmpty { p += "正确答案是：\(q.correctAnswer)。" }
        p += "请讲清楚为什么，并教我下次怎么做对。"
        return p
    }

    // MARK: Helpers

    private var accuracyTint: Color {
        switch workbook.accuracy {
        case 0.85...: .dbSuccess
        case 0.6..<0.85: .dbPrimary
        default: .dbWarning
        }
    }

    private func verdictTint(_ v: GradeVerdict) -> Color {
        switch v {
        case .correct: .dbSuccess
        case .incorrect: .dbError
        case .partial: .dbWarning
        case .unattempted: .dbTextTertiary
        case .ungradable: .dbInfo
        }
    }

    private func cardFill(_ v: GradeVerdict) -> Color {
        switch v {
        case .correct: .dbSuccessSoft
        case .incorrect: .dbErrorSoft
        default: .dbSurface
        }
    }

    static func num(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}
