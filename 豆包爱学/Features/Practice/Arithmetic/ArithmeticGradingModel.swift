//
//  ArithmeticGradingModel.swift
//  豆包爱学 — Features/Practice/Arithmetic
//
//  View model for 口算批改 (F32). Owns the editable worksheet of `ArithmeticItem`s,
//  drives OCR + `intelligence.gradeArithmetic`, exposes a `ViewState<GradedArithmetic>`
//  for the results screen, and persists wrong items into the 错题本 (`MistakeItem`).
//
//  The model is the single source of truth for the grading flow; the view binds to it
//  and never computes correctness itself (the on-device evaluator does that).
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class ArithmeticGradingModel {

    // MARK: Worksheet input (editable)

    /// The items the student wrote. Edited freely before grading; never empty after a
    /// successful prefill (sample / OCR / manual add).
    var items: [ArithmeticItem] = []

    /// Grade level used for the grading request (affects difficulty messaging).
    var grade: GradeLevel = .g3

    // MARK: Grading output

    /// Drives the results screen. `.idle` → input form; `.loaded` → annotated results.
    var state: ViewState<GradedArithmetic> = .idle

    /// True after wrong items have been pushed to the 错题本 for the *current* result,
    /// so the button reads "已加入错题本" and disables.
    var savedToNotebook = false

    /// Number of wrong items actually inserted on the last save (for the toast/banner).
    var lastSavedCount = 0

    // MARK: Derived

    /// Items with a real expression — the ones we can grade.
    var gradableItems: [ArithmeticItem] {
        items.filter { !$0.expression.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var canGrade: Bool { !gradableItems.isEmpty }

    var graded: GradedArithmetic? {
        if case let .loaded(value) = state { return value }
        return nil
    }

    var wrongItems: [GradedArithmeticItem] {
        graded?.items.filter { !$0.isCorrect } ?? []
    }

    var allCorrect: Bool {
        guard let graded, graded.total > 0 else { return false }
        return graded.correctCount == graded.total
    }

    var accuracy: Double {
        guard let graded, graded.total > 0 else { return 0 }
        return Double(graded.correctCount) / Double(graded.total)
    }

    // MARK: - Worksheet editing

    func loadSample() {
        items = ContentCatalog.sampleArithmetic
        resetResult()
    }

    func addBlankItem() {
        items.append(ArithmeticItem(expression: "", studentAnswer: ""))
        resetResult()
    }

    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        resetResult()
    }

    func clearAll() {
        items.removeAll()
        resetResult()
    }

    /// Replace the worksheet with OCR-recognized items, falling back to the sample
    /// worksheet when recognition yields nothing (no camera / blank photo on simulator).
    func applyRecognized(_ recognized: [ArithmeticItem]) {
        items = recognized.isEmpty ? ContentCatalog.sampleArithmetic : recognized
        resetResult()
    }

    /// Clears any prior grading so edits return the UI to the input form.
    private func resetResult() {
        if case .loaded = state {
            state = .idle
        }
        savedToNotebook = false
        lastSavedCount = 0
    }

    // MARK: - OCR

    /// Recognize arithmetic items from a worksheet photo using the on-device OCR service.
    /// Always resolves to a usable worksheet (sample fallback when empty).
    func recognize(imageData: Data, using ocr: OCRService) async {
        let recognized = await ocr.recognizeArithmeticItems(in: imageData)
        applyRecognized(recognized)
    }

    // MARK: - Grading

    func grade(using intelligence: any IntelligenceService, context: ModelContext) async {
        let toGrade = gradableItems
        guard !toGrade.isEmpty else {
            state = .empty(message: "先添加或拍摄几道题再批改吧～")
            return
        }
        state = .loading
        savedToNotebook = false
        lastSavedCount = 0
        do {
            let request = ArithmeticGradeRequest(items: toGrade, grade: grade)
            let result = try await intelligence.gradeArithmetic(request)
            if result.items.isEmpty {
                state = .empty(message: "没有可批改的题目")
            } else {
                state = .loaded(result)
                // Count the graded items toward the 答题足迹 contribution heatmap.
                ActivityRecorder.log(
                    context, kind: .practice, subject: .math,
                    questions: result.items.count,
                    detail: "口算批改 · \(result.items.count) 题")
            }
        } catch {
            state = .error(message: "批改失败，请稍后再试。")
        }
    }

    /// Start over from the input form (再批一组).
    func startOver() {
        state = .idle
        savedToNotebook = false
        lastSavedCount = 0
    }

    // MARK: - Persistence (错题本)

    /// Insert one `MistakeItem` per wrong item into SwiftData and save.
    /// Idempotent for a given result via `savedToNotebook`.
    @discardableResult
    func addWrongItemsToNotebook(context: ModelContext) -> Int {
        guard !savedToNotebook else { return 0 }
        let wrong = wrongItems
        guard !wrong.isEmpty else { return 0 }

        for graded in wrong {
            let mistake = MistakeItem()
            mistake.subject = .math
            mistake.questionText = graded.expression
            mistake.studentAnswer = graded.studentAnswer
            mistake.correctAnswer = graded.correctAnswer
            mistake.errorReason = graded.explanation.isEmpty
                ? "正确答案是 \(graded.correctAnswer)。"
                : graded.explanation
            mistake.errorType = graded.errorType ?? .calculation
            mistake.mastery = .new
            mistake.steps = [
                SolutionStep(
                    index: 0,
                    title: "正确答案",
                    detail: "\(graded.expression) = \(graded.correctAnswer)",
                    math: "\(graded.expression)=\(graded.correctAnswer)"
                )
            ]
            context.insert(mistake)
        }
        context.saveLogging()

        savedToNotebook = true
        lastSavedCount = wrong.count
        return wrong.count
    }
}
