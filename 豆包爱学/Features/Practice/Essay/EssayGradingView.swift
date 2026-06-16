//
//  EssayGradingView.swift
//  豆包爱学 — Features/Practice/Essay
//
//  作文批改 (F31). Entry point wired to `ToolKind.gradeEssay`. Flow:
//    1. 录入 — 选 语文/英语 + 年级 + 考试类型 → 粘贴/输入正文 (用示例 / 拍照识别(iOS)
//       / 相册 / 选择文件(macOS)) + 可选题目要求.
//    2. 批改 — `intelligence.gradeEssay` (Mock 返回 praising-first 反馈).
//    3. 反馈 — 综合点评 → 评分环 + 各维度雷达/柱状 (Swift Charts) → 分句点评 (按 severity
//       上色) → 升格作文 (原文/升格 切换，新增内容高亮) → 高分表达 chips → 朗读修改 (TTS).
//       范文/升格 在「学习模式」开启时先锁，需家长验证 (router.present(.parentGate)).
//
//  All ViewState branches handled; full Dark Mode via semantic Color.db*; both
//  platforms supported (相机仅 iOS，macOS 走文件导入/手输). The view is a thin
//  presenter over `EssayGradingModel`.
//

import SwiftUI
import SwiftData
import PhotosUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct EssayGradingView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(TTSService.self) private var tts
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query private var profiles: [LearnerProfile]
    @Query private var parentControlsRows: [ParentControls]

    @State private var model = EssayGradingModel()
    @State private var photoSelection: PhotosPickerItem?
    @State private var isRecognizing = false
    @State private var didApplyDefaults = false
    /// Set when the learner asks to reveal the model essay behind the parent gate;
    /// the reveal then happens once a guardian actually verifies (see .onChange).
    @State private var pendingModelEssayUnlock = false

    #if canImport(UIKit)
    @State private var showCamera = false
    #endif
    #if os(macOS)
    @State private var showFileImporter = false
    #endif

    private var isRegular: Bool { sizeClass != .compact }

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                switch model.state {
                case .idle:
                    composeSection
                case .loading:
                    DBStateView(kind: .loading,
                                title: "正在批改…",
                                message: "豆包正在通读全文，先找闪光点，再给建议")
                        .frame(maxWidth: .infinity, minHeight: 340)
                case let .loaded(feedback):
                    EssayFeedbackView(
                        feedback: feedback,
                        originalText: model.essayText,
                        subject: model.subject,
                        examTypeName: model.examType.displayName,
                        isRegular: isRegular,
                        modelEssayUnlocked: model.modelEssayUnlocked,
                        onSpeak: speak(_:language:),
                        onStopSpeak: { tts.stop() },
                        onUnlockModelEssay: requestModelEssayUnlock,
                        onPracticeSameType: openSameTypePractice,
                        onBackToEditing: { model.backToEditing() }
                    )
                case let .empty(message):
                    DBStateView(kind: .empty,
                                title: "还没有作文",
                                message: message,
                                systemImage: "doc.text",
                                retry: { model.loadSample() })
                        .frame(maxWidth: .infinity, minHeight: 280)
                    composeSection
                case let .error(message):
                    DBStateView(kind: .error,
                                title: "批改没完成",
                                message: message,
                                retry: { Task { await model.grade(using: intelligence, context: modelContext) } })
                        .frame(maxWidth: .infinity, minHeight: 280)
                    composeSection
                case let .offline(message):
                    DBStateView(kind: .offline, title: "离线模式", message: message)
                        .frame(maxWidth: .infinity, minHeight: 280)
                    composeSection
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("作文批改")
        .onChange(of: parentVerified) { _, verified in
            // A guardian verified after the gate was requested → reveal now.
            if verified, pendingModelEssayUnlock {
                model.modelEssayUnlocked = true
                pendingModelEssayUnlock = false
                HapticEngine.play(.success)
            }
        }
        .onAppear(perform: applyDefaultsOnce)
        .task(id: photoSelection) { await loadSelectedPhoto() }
        #if canImport(UIKit)
        .sheet(isPresented: $showCamera) {
            EssayCameraPicker { data in
                Task { await recognize(imageData: data) }
            }
            .ignoresSafeArea()
        }
        #endif
        #if os(macOS)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image, .plainText]) { result in
            if case let .success(url) = result {
                if let text = String.essayText(from: url) {
                    appendImported(text)
                } else if let data = Data.essayImage(from: url) {
                    Task { await recognize(imageData: data) }
                }
            }
        }
        #endif
    }

    // MARK: - Compose

    private var composeSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            introCard
            settingsCard
            captureCard
            editorCard
            gradeButton
        }
    }

    private var introCard: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                DBMascot(mood: .curious, size: 64)
                VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                    Text("作文批改")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("粘贴或拍下你的作文，豆包先夸优点，再做分句点评、给出升格作文与高分表达。")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                    Label("我只当教练，不替你写作文", systemImage: "hand.raised.fill")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbPrimaryDeep)
                        .padding(.top, DBSpacing.xxs)
                }
            }
        }
    }

    private var settingsCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("批改设置", subtitle: "选择学科、年级与评分标准", systemImage: "slider.horizontal.3")

                // 学科
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("学科").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                    HStack(spacing: DBSpacing.sm) {
                        subjectButton(.chinese, title: "语文")
                        subjectButton(.english, title: "英语")
                    }
                }

                // 年级
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("年级").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                    Picker("年级", selection: $model.grade) {
                        ForEach(GradeLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.dbPrimary)
                }

                // 评分标准
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("评分标准").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                    DBFlowLayout(spacing: DBSpacing.sm) {
                        ForEach(EssayExamType.options(for: model.subject)) { type in
                            Button {
                                model.examType = type
                                HapticEngine.play(.selection)
                            } label: {
                                DBChip(type.displayName,
                                       systemImage: type == .none ? "pencil.line" : "rosette",
                                       tint: .dbSecondary,
                                       isSelected: model.examType == type)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func subjectButton(_ subject: Subject, title: String) -> some View {
        Button {
            guard model.subject != subject else { return }
            model.subject = subject
            // 切换学科时修正评分标准（英语才有 IELTS）。
            if !EssayExamType.options(for: subject).contains(model.examType) {
                model.examType = .none
            }
            HapticEngine.play(.selection)
        } label: {
            DBChip(title,
                   systemImage: subject == .english ? "character.book.closed.fill" : "character.book.closed",
                   tint: DBSubjectColor.color(for: subject),
                   isSelected: model.subject == subject)
        }
        .buttonStyle(.plain)
    }

    private var captureCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("录入作文", subtitle: "选择一种方式录入正文", systemImage: "tray.and.arrow.down.fill")

                DBFlowLayout(spacing: DBSpacing.sm) {
                    #if canImport(UIKit)
                    captureButton(title: "拍照识别", systemImage: "camera.fill") {
                        showCamera = true
                    }
                    #endif

                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Label("从相册选", systemImage: "photo.on.rectangle.angled")
                            .font(.dbSubheadline)
                            .foregroundStyle(Color.dbPrimaryDeep)
                            .padding(.horizontal, DBSpacing.md)
                            .padding(.vertical, DBSpacing.sm)
                            .background(Color.dbPrimarySoft, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    #if os(macOS)
                    captureButton(title: "选择文件", systemImage: "folder.fill") {
                        showFileImporter = true
                    }
                    #endif

                    captureButton(title: "用示例", systemImage: "sparkles") {
                        model.loadSample()
                        HapticEngine.play(.selection)
                    }

                    if !model.essayText.isEmpty {
                        captureButton(title: "清空", systemImage: "trash") {
                            model.essayText = ""
                            HapticEngine.play(.selection)
                        }
                    }
                }

                if isRecognizing {
                    HStack(spacing: DBSpacing.xs) {
                        ProgressView()
                        Text("正在识别文字…")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                }

                #if os(macOS)
                Text("Mac 端不支持相机，可选择图片 / PDF / 文本文件，或直接在下方输入。")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextTertiary)
                #endif
            }
        }
    }

    private func captureButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { captureChipLabel(title: title, systemImage: systemImage) }
            .buttonStyle(.plain)
    }

    private func captureChipLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.dbSubheadline)
            .foregroundStyle(Color.dbPrimaryDeep)
            .padding(.horizontal, DBSpacing.md)
            .padding(.vertical, DBSpacing.sm)
            .background(Color.dbPrimarySoft, in: Capsule())
    }

    private var editorCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("题目与正文", subtitle: "题目可留空，正文必填", systemImage: "square.and.pencil") {
                    Text("\(model.wordCount) 字")
                        .font(.dbCaption.monospacedDigit())
                        .foregroundStyle(Color.dbTextTertiary)
                }

                TextField(model.subject == .english ? "题目（选填），如 My Dream" : "题目（选填），如 我的理想",
                          text: $model.prompt)
                    .font(.dbBody)
                    .textFieldStyle(.plain)
                    .padding(DBSpacing.sm)
                    .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))

                essayEditor

                writingToolsHint
            }
        }
    }

    /// Surfaces the system Writing Tools affordance on the essay editor and frames
    /// it for K12 use: 系统写作工具帮你校对、润色，但豆包只当教练，不替你写作文。
    private var writingToolsHint: some View {
        Label {
            Text("长按或选中文字可调用系统「写作工具」校对、润色 — 它帮你检查，但请用自己的话写作，豆包只当教练。")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "pencil.and.scribble")
                .font(.dbCaption)
                .foregroundStyle(Color.dbPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("选中正文后可使用系统写作工具进行校对与润色")
    }

    @ViewBuilder private var essayEditor: some View {
        ZStack(alignment: .topLeading) {
            if model.essayText.isEmpty {
                Text(model.subject == .english
                     ? "在这里粘贴或输入英语作文…"
                     : "在这里粘贴或输入作文正文…")
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextTertiary)
                    .padding(.horizontal, DBSpacing.sm + 4)
                    .padding(.vertical, DBSpacing.sm + 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $model.essayText)
                .font(.dbBody)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(DBSpacing.xs)
                // First-class TextEditor → gets system Writing Tools (校对/润色/改写)
                // automatically on iOS 26 / macOS 26. `.complete` opts into the full
                // inline + panel experience for proofreading & rewriting an essay.
                .writingToolsBehavior(.complete)
                .accessibilityLabel("作文正文输入框")
                .accessibilityHint("可粘贴或输入作文，选中文字后可使用系统写作工具")
        }
        .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
    }

    private var gradeButton: some View {
        Button {
            HapticEngine.play(.light)
            Task { await model.grade(using: intelligence, context: modelContext) }
        } label: {
            Label("开始批改", systemImage: "checkmark.seal.fill")
        }
        .buttonStyle(.db(.primary, fullWidth: true))
        .disabled(!model.canGrade)
        .opacity(model.canGrade ? 1 : 0.5)
    }

    // MARK: - Actions

    private func applyDefaultsOnce() {
        guard !didApplyDefaults else { return }
        didApplyDefaults = true
        model.applyDefaults(from: profiles.first)
    }

    private func recognize(imageData: Data) async {
        isRecognizing = true
        let found = await model.ingest(imageData: imageData, using: ocr)
        isRecognizing = false
        HapticEngine.play(found ? .selection : .warning)
    }

    private func appendImported(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if model.essayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.essayText = trimmed
        } else {
            model.essayText += "\n" + trimmed
        }
        HapticEngine.play(.selection)
    }

    private func loadSelectedPhoto() async {
        guard let photoSelection else { return }
        isRecognizing = true
        defer { isRecognizing = false; self.photoSelection = nil }
        if let data = try? await photoSelection.loadTransferable(type: Data.self) {
            let found = await model.ingest(imageData: data, using: ocr)
            HapticEngine.play(found ? .selection : .warning)
        } else {
            HapticEngine.play(.warning)
        }
    }

    private func speak(_ text: String, language: String) {
        if tts.isSpeaking { tts.stop() }
        tts.speak(text, language: language)
    }

    private var learnModeEnabled: Bool { profiles.first?.learnModeEnabled ?? true }
    private var parentVerified: Bool { parentControlsRows.first?.verified ?? false }

    /// 范文/升格作文 reveal. With 学习模式 ON this is gated behind real parent
    /// verification so the app "coaches, doesn't write" — the reveal only happens
    /// once `ParentControls.verified` is true (immediately if already verified or if
    /// Learn Mode is off, otherwise after the guardian completes the gate). Presenting
    /// the gate no longer unlocks on its own, closing the bypass.
    private func requestModelEssayUnlock() {
        guard !model.modelEssayUnlocked else { return }
        HapticEngine.play(.light)
        if !learnModeEnabled || parentVerified {
            model.modelEssayUnlocked = true
            return
        }
        pendingModelEssayUnlock = true
        router.present(.parentGate(reason: "查看升格范文需要家长确认，避免直接照抄。"))
    }

    /// 同类练手题: hand the prompt/topic to the tutor for a same-type writing drill.
    private func openSameTypePractice() {
        let topic = model.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = topic.isEmpty ? (model.subject == .english ? "My Dream" : "我的理想") : topic
        HapticEngine.play(.light)
        let ask = model.subject == .english
            ? "请围绕「\(seed)」出一道同类英语作文练习题，并给出 3 个写作提示。"
            : "请围绕「\(seed)」出一道同类作文练习题，并给出 3 个审题与立意的提示。"
        router.present(.tutor(problemText: ask, subject: model.subject, grade: model.grade))
    }
}

// MARK: - Preview

#Preview("作文批改") {
    NavigationStack {
        EssayGradingView()
    }
    .modelContainer(ModelContainerFactory.make(inMemory: true))
    .environment(AppRouter())
    .environment(TTSService())
}
