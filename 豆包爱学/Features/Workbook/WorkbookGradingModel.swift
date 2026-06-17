//
//  WorkbookGradingModel.swift
//  豆包爱学 — Features/Workbook
//
//  The @Observable view model behind 作业批改. It owns the capture → grade → persist
//  lifecycle through a single `ViewState<GradedWorkbook>`:
//
//    1. acquire   — camera / 相册 / 文件 yields image `Data` (held for the request
//                   and for re-rendering history).
//    2. grade     — on-device OCR pre-pass, then `intelligence.gradeWorkbook(_:)`
//                   (vision model when the provider supports it; OCR-text otherwise;
//                   deterministic offline engine as the universal fallback).
//    3. persist   — a `WorkbookGradeRecord` (photo + structured result + metadata)
//                   lands in 批改历史 so the grading is permanent and re-openable.
//
//  Saving wrong questions to the 错题本 / 题库 is also driven here so the result view
//  stays declarative.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class WorkbookGradingModel {
    var state: ViewState<GradedWorkbook> = .idle
    /// nil = let the model auto-detect each question's subject.
    var subjectHint: Subject?
    var grade: GradeLevel = .g5
    var learnMode: Bool = true

    private(set) var imageData: Data?
    private(set) var source: ProblemSource = .camera
    private(set) var savedRecordID: UUID?

    var hasImage: Bool { imageData != nil }
    var isWorking: Bool { state.isLoading }

    var previewImage: Image? { imageData.flatMap { Image.fromWorkbookData($0) } }

    static let selectableSubjects: [Subject] = [
        .math, .chinese, .english, .physics, .chemistry, .biology, .science, .general,
    ]

    // MARK: Image acquisition

    /// Accept freshly captured / picked / imported image bytes (camera + Photos paths
    /// already normalize; this re-encodes a file import on macOS).
    func setImage(_ data: Data, source: ProblemSource) {
        #if os(macOS)
        imageData = WorkbookImagePrep.normalizedJPEG(from: data) ?? data
        #else
        imageData = data
        #endif
        self.source = source
        // A new image invalidates any prior result.
        if state.value != nil { state = .idle }
        savedRecordID = nil
        HapticEngine.play(.light)
    }

    func reset() {
        state = .idle
        imageData = nil
        savedRecordID = nil
    }

    // MARK: Grade

    func grade(using intelligence: any IntelligenceService, ocr: OCRService, context: ModelContext) async {
        guard let data = imageData else {
            state = .empty(message: "先拍照、从相册选择，或上传一张作业图片吧。")
            return
        }
        state = .loading
        // On-device OCR pre-pass: a hint for vision models, the sole input for text-only.
        let recognized = await ocr.recognizeText(in: data)
        let request = WorkbookGradeRequest(
            imageData: data, recognizedText: recognized,
            subjectHint: subjectHint, grade: grade, learnMode: learnMode)
        do {
            let result = try await intelligence.gradeWorkbook(request)
            guard !result.questions.isEmpty else {
                state = .empty(message: "没有从图片里识别到题目。换一张更清晰、更端正的照片再试试吧。")
                return
            }
            state = .loaded(result)
            persist(result, context: context)
            // Count every graded question toward the daily 答题足迹 contribution graph.
            ActivityRecorder.log(
                context, kind: .workbook, subject: result.primarySubject,
                questions: result.total, detail: "作业批改 · \(result.title)")
            HapticEngine.play(.success)
        } catch {
            state = .error(message: "批改没有完成。请检查网络，或换一张更清晰的照片重试。")
            HapticEngine.play(.error)
        }
    }

    /// Deterministic demo result — always works, no network, no photo needed.
    func runSample(context: ModelContext) async {
        source = .text
        imageData = nil
        state = .loading
        try? await Task.sleep(nanoseconds: 500_000_000)
        let result = MockContent.sampleGradedWorkbook(subjectHint: subjectHint, grade: grade)
        state = .loaded(result)
        persist(result, context: context)
        HapticEngine.play(.success)
    }

    // MARK: Persistence — WorkbookGradeRecord (批改历史)

    private func persist(_ workbook: GradedWorkbook, context: ModelContext) {
        // Idempotent: re-grading the same capture updates the existing record.
        if let id = savedRecordID,
           let existing = try? context.fetch(
            FetchDescriptor<WorkbookGradeRecord>(predicate: #Predicate { $0.id == id })).first {
            existing.title = workbook.title
            existing.result = workbook
            existing.subject = workbook.primarySubject
            existing.grade = workbook.grade
            existing.totalCount = workbook.total
            existing.correctCount = workbook.correctCount
            existing.wrongCount = workbook.wrongQuestions.count
            existing.scoreEarned = workbook.scoreEarned
            existing.scorePossible = workbook.scorePossible
            existing.route = workbook.route
        } else {
            let record = WorkbookGradeRecord.make(from: workbook, imageData: imageData)
            context.insert(record)
            savedRecordID = record.id
        }
        context.saveLogging()
    }
}
