//
//  CaptureSolveView.swift
//  豆包爱学 — Features/Solve
//
//  拍照解题 capture surface (RESEARCH §4.1 F1–F5, F9, F10). Presented as a sheet
//  via `AppSheet.capture(mode)`. The universal input funnel: on iOS it offers a
//  live camera + 相册 PhotosPicker; on macOS it falls back to file import; on every
//  platform it offers a typed/pasted text path and "试试示例" sample problems.
//
//  After acquiring text (OCR on an image, or typed), it shows an editable
//  recognized-question card (math rendered with MathText), an auto-detected
//  subject chip the learner can correct, then "开始解答" → SolveResultView.
//

import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// MARK: - Capture surface

/// The capture/import sheet for 拍照解题. `mode` forks 拍题 (solve) vs 批改 (grade);
/// this view drives the **solve** path end-to-end. In grade mode it still captures
/// a question and routes to the structured solver (the dedicated 口算批改 grid is a
/// separate tool), so the sheet is always useful no matter how it is presented.
struct CaptureSolveView: View {
    let mode: CaptureMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ocr) private var ocr
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var profiles: [LearnerProfile]

    @State private var model: CaptureSolveModel

    init(mode: CaptureMode) {
        self.mode = mode
        _model = State(initialValue: CaptureSolveModel(mode: mode))
    }

    private var profile: LearnerProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DBSpacing.lg) {
                    header
                    captureSurface
                    if model.hasRecognizedText {
                        recognizedCard
                        subjectPicker
                        startButton
                    } else {
                        inputOptions
                        sampleSection
                    }
                }
                .padding(DBSpacing.screenInset)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Color.dbBackground)
            .navigationTitle(mode == .solve ? "拍照解题" : "拍照批改")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                if model.hasRecognizedText {
                    ToolbarItem(placement: .primaryAction) {
                        Button("重拍") { model.reset() }
                    }
                }
            }
            .navigationDestination(isPresented: $model.showResult) {
                SolveResultView(
                    recognizedText: model.recognizedText,
                    subject: model.subject,
                    grade: profile?.grade ?? .g5,
                    source: model.source,
                    imageData: model.imageData,
                    learnModeEnabled: profile?.learnModeEnabled ?? true
                )
            }
        }
        #if os(iOS)
        .photosPicker(isPresented: $model.showPhotoPicker, selection: $model.photoSelection, matching: .images)
        .onChange(of: model.photoSelection) { _, newValue in
            guard let newValue else { return }
            Task { await model.loadPickedPhoto(newValue, ocr: ocr) }
        }
        #endif
        .alert("识别失败", isPresented: $model.showRecognitionAlert) {
            Button("好的", role: .cancel) {}
            Button("手动输入") { model.beginManualInput() }
        } message: {
            Text("没有从图片里读到文字。可以重拍清晰一点，或者直接手动输入题目。")
        }
    }

    // MARK: Header

    private var header: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: model.isWorking ? .thinking : .curious, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode == .solve ? "一拍即解，思路全在这" : "拍下题目，我来帮你检查")
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("支持拍照、相册、文档与手动输入，全学科覆盖")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Capture surface (preview or guide)

    @ViewBuilder private var captureSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous)
                .fill(Color.dbSurfaceRaised)
            if let image = model.previewImage {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous))
            } else {
                captureGuide
            }
            if model.isWorking {
                ZStack {
                    RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous)
                        .fill(.ultraThinMaterial)
                    VStack(spacing: DBSpacing.sm) {
                        ProgressView().controlSize(.large).tint(Color.dbPrimary)
                        Text("正在识别题目…").font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                    }
                }
            }
        }
        .frame(height: model.previewImage == nil ? 200 : 280)
        .overlay(
            RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous)
                .strokeBorder(Color.dbSeparator, lineWidth: 1)
        )
    }

    private var captureGuide: some View {
        VStack(spacing: DBSpacing.sm) {
            RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                .strokeBorder(Color.dbPrimary.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                .frame(width: 132, height: 86)
                .overlay {
                    Image(systemName: mode == .solve ? "camera.viewfinder" : "checkmark.rectangle.stack")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.dbPrimary)
                }
            Text("把题目放进取景框里")
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextTertiary)
        }
    }

    // MARK: Input options

    private var inputOptions: some View {
        VStack(spacing: DBSpacing.md) {
            #if os(iOS)
            HStack(spacing: DBSpacing.md) {
                captureTile("拍照", systemImage: "camera.fill", tint: .dbPrimary) {
                    model.beginCameraCapture()
                }
                captureTile("相册", systemImage: "photo.on.rectangle", tint: .dbSecondary) {
                    model.showPhotoPicker = true
                }
            }
            HStack(spacing: DBSpacing.md) {
                captureTile("手动输入", systemImage: "text.cursor", tint: .dbAccent) {
                    model.beginManualInput()
                }
                captureTile("用示例题", systemImage: "wand.and.stars", tint: .dbInfo) {
                    model.useFirstSample()
                }
            }
            #else
            HStack(spacing: DBSpacing.md) {
                captureTile("导入图片", systemImage: "photo.on.rectangle", tint: .dbPrimary) {
                    model.importFileMac(ocr: ocr)
                }
                captureTile("手动输入", systemImage: "text.cursor", tint: .dbAccent) {
                    model.beginManualInput()
                }
            }
            HStack(spacing: DBSpacing.md) {
                captureTile("用示例题", systemImage: "wand.and.stars", tint: .dbInfo) {
                    model.useFirstSample()
                }
                Color.clear.frame(maxWidth: .infinity)
            }
            #endif

            if model.isManualInput {
                manualInputCard
            }
        }
    }

    private func captureTile(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DBSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.14), in: Circle())
                Text(title).font(.dbFootnote.weight(.medium)).foregroundStyle(Color.dbTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DBSpacing.md)
            .dbSurfaceStyle(cornerRadius: DBRadius.lg, fill: .dbSurface, elevation: .low)
        }
        .buttonStyle(.plain)
    }

    private var manualInputCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Label("输入或粘贴题目", systemImage: "square.and.pencil")
                    .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                TextEditor(text: $model.draftText)
                    .font(.dbBody)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(DBSpacing.sm)
                    .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if model.draftText.isEmpty {
                            Text("例如：一个长方形长 8 厘米，宽 5 厘米，面积是多少？")
                                .font(.dbBody).foregroundStyle(Color.dbTextTertiary)
                                .padding(DBSpacing.sm + 4)
                                .allowsHitTesting(false)
                        }
                    }
                Button("确认题目") { model.commitDraft() }
                    .buttonStyle(.db(.primary, fullWidth: true))
                    .disabled(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: Sample problems

    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("试试示例", subtitle: "点一道题，立即体验完整解析", systemImage: "sparkles")
            ForEach(model.sampleProblems) { problem in
                Button {
                    model.useSample(problem)
                } label: {
                    DBCard {
                        HStack(spacing: DBSpacing.md) {
                            DBSubjectChip(problem.subject)
                            MathText(problem.text, font: .dbCallout)
                                .foregroundStyle(Color.dbTextPrimary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.dbFootnote).foregroundStyle(Color.dbTextTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Recognized-question card

    private var recognizedCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack {
                    Label("识别到的题目", systemImage: "doc.text.viewfinder")
                        .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                    Spacer()
                    Button(model.isEditingRecognized ? "完成" : "修改") {
                        model.isEditingRecognized.toggle()
                    }
                    .font(.dbFootnote.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.dbPrimary)
                }
                if model.isEditingRecognized {
                    TextEditor(text: $model.recognizedText)
                        .font(.dbBody)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(DBSpacing.sm)
                        .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                } else {
                    MathText(model.recognizedText, font: .dbBody)
                        .foregroundStyle(Color.dbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("识别可能有误？点「修改」校对后再解答，避免答错。")
                    .font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
            }
        }
    }

    // MARK: Subject picker (auto-detected, correctable)

    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            Text("学科").font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.sm) {
                    ForEach(CaptureSolveModel.selectableSubjects) { subject in
                        Button {
                            model.subject = subject
                            HapticEngine.play(.selection)
                        } label: {
                            DBSubjectChip(subject, isSelected: model.subject == subject)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Start button

    private var startButton: some View {
        Button {
            model.start()
        } label: {
            Label("开始解答", systemImage: "wand.and.stars")
        }
        .buttonStyle(.db(.primary, fullWidth: true))
        .disabled(model.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

// MARK: - Capture model

@MainActor
@Observable
final class CaptureSolveModel {
    let mode: CaptureMode

    var draftText: String = ""
    var recognizedText: String = ""
    var subject: Subject = .math
    var source: ProblemSource = .text
    var imageData: Data?

    var isManualInput = false
    var isEditingRecognized = false
    var isWorking = false
    var showResult = false

    var showPhotoPicker = false
    var photoSelection: PhotosPickerItem?
    var showRecognitionAlert = false

    #if canImport(UIKit)
    private var pickedUIImage: UIImage?
    #endif
    #if os(macOS)
    private var pickedNSImage: NSImage?
    #endif

    init(mode: CaptureMode) {
        self.mode = mode
    }

    var hasRecognizedText: Bool {
        !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    let sampleProblems: [CatalogProblem] = ContentCatalog.sampleProblems

    static let selectableSubjects: [Subject] = [
        .math, .physics, .chemistry, .biology, .chinese, .english, .science, .general
    ]

    var previewImage: Image? {
        #if canImport(UIKit)
        if let img = pickedUIImage { return Image(uiImage: img) }
        #endif
        #if os(macOS)
        if let img = pickedNSImage { return Image(nsImage: img) }
        #endif
        return nil
    }

    // MARK: Input flows

    func beginManualInput() {
        isManualInput = true
    }

    func commitDraft() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recognizedText = trimmed
        source = .text
        subject = MockContent.inferSubject(from: trimmed)
        isManualInput = false
        HapticEngine.play(.light)
    }

    func useSample(_ problem: CatalogProblem) {
        recognizedText = problem.text
        subject = problem.subject
        source = .text
        HapticEngine.play(.light)
    }

    func useFirstSample() {
        if let first = sampleProblems.first { useSample(first) }
    }

    func reset() {
        recognizedText = ""
        draftText = ""
        imageData = nil
        isManualInput = false
        isEditingRecognized = false
        isWorking = false
        #if canImport(UIKit)
        pickedUIImage = nil
        #endif
        #if os(macOS)
        pickedNSImage = nil
        #endif
        photoSelection = nil
    }

    // MARK: Camera (iOS) — handled by parent via PhotosPicker; camera tile opens picker as a graceful default

    func beginCameraCapture() {
        // The viewfinder camera is an iOS-only integration seam; until a live
        // camera session is wired, opening the photo library lets the learner
        // pick a freshly-shot photo, keeping the solve flow fully functional.
        showPhotoPicker = true
    }

    // MARK: OCR

    #if os(iOS)
    func loadPickedPhoto(_ item: PhotosPickerItem, ocr: OCRService) async {
        isWorking = true
        defer { isWorking = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            showRecognitionAlert = true
            return
        }
        imageData = data
        source = .album
        #if canImport(UIKit)
        pickedUIImage = UIImage(data: data)
        #endif
        await recognize(data: data, ocr: ocr)
    }
    #endif

    #if os(macOS)
    func importFileMac(ocr: OCRService) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        imageData = data
        source = .document
        pickedNSImage = NSImage(data: data)
        Task { await recognizeMac(data: data, ocr: ocr) }
    }

    private func recognizeMac(data: Data, ocr: OCRService) async {
        isWorking = true
        defer { isWorking = false }
        await recognize(data: data, ocr: ocr)
    }
    #endif

    private func recognize(data: Data, ocr: OCRService) async {
        let text = await ocr.recognizeText(in: data).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            showRecognitionAlert = true
        } else {
            recognizedText = text
            subject = MockContent.inferSubject(from: text)
            isEditingRecognized = false
            HapticEngine.play(.success)
        }
    }

    // MARK: Solve

    func start() {
        guard hasRecognizedText else { return }
        isEditingRecognized = false
        showResult = true
        HapticEngine.play(.light)
    }
}

// MARK: - Preview

#Preview("拍照解题 · 拍题") {
    CaptureSolveView(mode: .solve)
        .modelContainer(for: [LearnerProfile.self, ProblemRecord.self, MistakeItem.self], inMemory: true)
}

#Preview("拍照解题 · 批改") {
    CaptureSolveView(mode: .grade)
        .modelContainer(for: [LearnerProfile.self, ProblemRecord.self, MistakeItem.self], inMemory: true)
}
