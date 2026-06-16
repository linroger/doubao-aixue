//
//  EssayGradingModel.swift
//  豆包爱学 — Features/Practice/Essay
//
//  View model for 作文批改 (F31). Owns the compose-then-grade flow: subject /
//  grade / exam-type selection, the essay text (typed, pasted, sample, or OCR'd),
//  the async call to `IntelligenceService.gradeEssay`, and persistence of an
//  `EssayRecord`. All UI state lives here; the view is a thin presenter.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class EssayGradingModel {

    // MARK: Composition inputs

    /// 作文批改 supports 语文 (Chinese) and 英语 (English) essays.
    var subject: Subject = .chinese
    var grade: GradeLevel = .g9
    var examType: EssayExamType = .none
    /// Optional 题目/写作要求 the student is responding to.
    var prompt: String = ""
    var essayText: String = ""

    // MARK: Grading state

    /// `EssayFeedback` is the only async payload; the compose screen shows when
    /// `state == .idle`, the result screen renders `.loaded`.
    private(set) var state: ViewState<EssayFeedback> = .idle

    /// Whether the full 升格作文 / 范文 is unlocked. When the learner profile has
    /// 学习模式 (anti-cheat) ON we keep it locked behind a parent gate so the app
    /// "coaches, doesn't write" — only 思路 is shown until a parent verifies.
    var modelEssayUnlocked: Bool = false

    var isGrading: Bool {
        if case .loading = state { return true }
        return false
    }

    var hasFeedback: Bool {
        if case .loaded = state { return true }
        return false
    }

    var feedback: EssayFeedback? {
        if case let .loaded(value) = state { return value }
        return nil
    }

    private var lastSavedRecordID: UUID?

    // MARK: Defaults from profile

    /// Seed grade / exam-type from the learner profile so the picker opens on the
    /// right values. Safe to call repeatedly; only applies before first grading.
    func applyDefaults(from profile: LearnerProfile?) {
        guard !hasFeedback, !isGrading else { return }
        if let profile {
            grade = profile.grade
            // 学习模式 ON → 范文 stays gated until a parent verifies.
            modelEssayUnlocked = !profile.learnModeEnabled
            if examType == .none {
                examType = EssayExamType.suggested(for: profile.grade)
            }
        }
    }

    // MARK: Sample / reset

    func loadSample() {
        if subject == .english {
            essayText = Self.sampleEnglishEssay
            if prompt.isEmpty { prompt = "My Dream" }
        } else {
            essayText = ContentCatalog.sampleEssay
            if prompt.isEmpty { prompt = "我的理想" }
        }
    }

    /// Return to the compose screen, keeping the current text so the student can
    /// tweak and re-grade.
    func backToEditing() {
        state = .idle
    }

    /// 拍照识别: run on-device OCR over a captured/imported page and append the
    /// recognised text to the editor. Returns `true` when text was found so the
    /// caller can give feedback (haptic / message) on an empty scan.
    @discardableResult
    func ingest(imageData: Data, using ocr: OCRService) async -> Bool {
        let recognised = await ocr.recognizeText(in: imageData)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recognised.isEmpty else { return false }
        if essayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            essayText = recognised
        } else {
            essayText += "\n" + recognised
        }
        return true
    }

    var canGrade: Bool {
        !essayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGrading
    }

    var wordCount: Int {
        essayText.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    // MARK: Grade

    func grade(using intelligence: any IntelligenceService, context: ModelContext) async {
        let trimmed = essayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .empty(message: "请先粘贴或输入一篇作文，再开始批改。")
            return
        }
        state = .loading
        HapticEngine.play(.light)

        let request = EssayGradeRequest(
            text: trimmed,
            subject: subject,
            examType: examType.requestValue,
            grade: grade,
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let feedback = try await intelligence.gradeEssay(request)
            state = .loaded(feedback)
            persist(feedback, originalText: trimmed, context: context)
            HapticEngine.play(.success)
        } catch IntelligenceError.emptyInput {
            state = .empty(message: "没有识别到文字，请重新粘贴或拍照。")
        } catch {
            state = .error(message: "批改没有完成，请稍后再试一次。")
            HapticEngine.play(.error)
        }
    }

    // MARK: Persistence

    /// Save an `EssayRecord` so the result lands in the student's history. We
    /// update the same record on re-grade rather than piling up duplicates.
    private func persist(_ feedback: EssayFeedback, originalText: String, context: ModelContext) {
        let record: EssayRecord
        if let id = lastSavedRecordID,
           let existing = try? context.fetch(
            FetchDescriptor<EssayRecord>(predicate: #Predicate { $0.id == id })
           ).first {
            record = existing
        } else {
            record = EssayRecord()
            context.insert(record)
            lastSavedRecordID = record.id
        }

        record.subject = subject
        record.title = derivedTitle(from: originalText)
        record.promptText = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        record.originalText = originalText
        record.overallComment = feedback.overallComment
        record.score = feedback.score
        record.maxScore = feedback.maxScore
        record.examType = examType.requestValue
        record.rubric = feedback.rubric
        record.annotations = feedback.annotations
        record.polishedText = feedback.polishedText
        record.highScoreExpressions = feedback.highScoreExpressions
        record.createdAt = Date()

        context.saveLogging()
    }

    private func derivedTitle(from text: String) -> String {
        if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // First sentence/line, capped — gives the record a human-readable title.
        let firstLine = text
            .split(whereSeparator: { $0 == "\n" || $0 == "。" || $0 == "." })
            .first
            .map(String.init) ?? text
        return String(firstLine.prefix(16))
    }

    // MARK: Sample English essay (catalog has Chinese only)

    static let sampleEnglishEssay = """
    My dream is to become a doctor. When I was little, my grandmother often fell ill, \
    and I felt sad because I could not help her. Doctors can save lives and bring hope \
    to many families. To make my dream come true, I study hard every day and never give up. \
    I believe that if I keep working hard, my dream will surely come true one day.
    """
}

// MARK: - Exam type

/// 评分标准 the rubric is referenced against. Chinese essays map to 中考/高考,
/// English essays additionally support IELTS.
nonisolated enum EssayExamType: String, CaseIterable, Identifiable, Sendable {
    case none
    case zhongkao   // 中考
    case gaokao     // 高考
    case ielts      // IELTS (English)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "随堂练习"
        case .zhongkao: "中考"
        case .gaokao: "高考"
        case .ielts: "IELTS"
        }
    }

    /// Value handed to the intelligence request (empty for 随堂练习).
    var requestValue: String {
        self == .none ? "" : displayName
    }

    /// Which exam types make sense for a subject. IELTS only for English.
    static func options(for subject: Subject) -> [EssayExamType] {
        if subject == .english {
            return [.none, .zhongkao, .gaokao, .ielts]
        }
        return [.none, .zhongkao, .gaokao]
    }

    /// A sensible default given the learner's grade.
    static func suggested(for grade: GradeLevel) -> EssayExamType {
        switch grade.stage {
        case .seniorHigh: .gaokao
        case .juniorHigh: .zhongkao
        default: .none
        }
    }
}
