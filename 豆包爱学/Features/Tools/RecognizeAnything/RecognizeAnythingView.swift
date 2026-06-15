//
//  RecognizeAnythingView.swift
//  豆包爱学 — Features/Tools/RecognizeAnything
//
//  识万物 (F25) — point the camera / pick a photo / import a file at an object,
//  plant, animal, food, landmark, English word, or math expression and get an
//  identification + a kid-friendly Chinese 讲解 + 相关知识点/延伸问题. Wired to
//  `ToolKind.recognizeAnything` via the no-argument `init()`.
//
//  • On-device recognition: Vision (VNClassifyImageRequest +
//    VNRecognizeAnimalsRequest) for the visual path, OCR for words / math.
//  • Kid-friendly 讲解 + 延伸问题 via the IntelligenceService, with a
//    deterministic offline fallback so it works on every platform.
//  • 朗读 (TTS) and 问豆包老师 (deep-links to the tutor sheet) actions.
//  • All ViewState branches handled; full Dark Mode via semantic Color.db*;
//    both platforms (camera iOS-only, file import + Photos elsewhere).
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct RecognizeAnythingView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(TTSService.self) private var tts
    @Environment(AppRouter.self) private var router
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @State private var model = RecognizeAnythingModel()
    @State private var photoSelection: PhotosPickerItem?

    #if os(iOS)
    @State private var showCamera = false
    #endif
    #if os(macOS)
    @State private var showFileImporter = false
    #endif

    init() {}

    private var grade: GradeLevel { .g5 }

    private var isRegular: Bool {
        #if os(iOS)
        sizeClass != .compact
        #else
        true
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                heroCard
                captureCard
                resultSection
            }
            .padding(DBSpacing.screenInset)
        }
        .background(Color.dbBackground)
        .navigationTitle("识万物")
        .task(id: photoSelection) { await loadSelectedPhoto() }
        #if os(iOS)
        .sheet(isPresented: $showCamera) {
            RecognizeCameraPicker { data in
                Task { await model.recognize(imageData: data, source: .camera,
                                             intelligence: intelligence, grade: grade) }
            }
            .ignoresSafeArea()
        }
        #endif
        #if os(macOS)
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.image]) { result in
            handleFileImport(result)
        }
        #endif
    }

    // MARK: Hero

    private var heroCard: some View {
        DBCard(fill: Color.dbSurfaceRaised, elevation: .medium) {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.dbPrimarySoft)
                        .frame(width: 56, height: 56)
                    Image(systemName: ToolKind.recognizeAnything.symbolName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.dbPrimary)
                }
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("对准万物，我来告诉你它是什么")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("植物 · 动物 · 食物 · 地标 · 物品 · 英文单词 · 算式，都可以拍来问我。")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Capture

    private var captureCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("开始识别", subtitle: "选择一种方式录入画面",
                                systemImage: "viewfinder")

                DBFlowLayout(spacing: DBSpacing.sm) {
                    #if os(iOS)
                    captureChip(title: "拍照识别", systemImage: "camera.fill") {
                        showCamera = true
                        HapticEngine.play(.selection)
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
                    captureChip(title: "选择图片", systemImage: "folder.fill") {
                        showFileImporter = true
                    }
                    #endif

                    captureChip(title: "试试示例", systemImage: "sparkles") {
                        Task { await model.runSample(intelligence: intelligence, grade: grade) }
                        HapticEngine.play(.selection)
                    }

                    if model.hasResult {
                        captureChip(title: "重新识别", systemImage: "arrow.counterclockwise") {
                            model.reset()
                            HapticEngine.play(.selection)
                        }
                    }
                }

                #if os(macOS)
                Text("Mac 端不支持相机，可从相册或文件选择一张图片，或点「试试示例」。")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextTertiary)
                #endif
            }
        }
    }

    private func captureChip(title: String, systemImage: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chipLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.dbSubheadline)
            .foregroundStyle(Color.dbPrimaryDeep)
            .padding(.horizontal, DBSpacing.md)
            .padding(.vertical, DBSpacing.sm)
            .background(Color.dbPrimarySoft, in: Capsule())
    }

    // MARK: Result section (ViewState)

    @ViewBuilder
    private var resultSection: some View {
        switch model.state {
        case .idle:
            tipsCard
        case .loading:
            recognizingView
        case .empty(let message):
            DBStateView(kind: .empty, title: "没有识别到", message: message)
                .frame(maxWidth: .infinity).frame(minHeight: 200)
        case .error(let message):
            DBStateView(kind: .error, title: "识别出错了", message: message,
                        retry: { model.reset() })
                .frame(maxWidth: .infinity).frame(minHeight: 200)
        case .offline(let message):
            DBStateView(kind: .offline, title: "离线模式", message: message)
                .frame(maxWidth: .infinity).frame(minHeight: 200)
        case .loaded(let result):
            resultView(result)
        }
    }

    private var recognizingView: some View {
        DBCard {
            VStack(spacing: DBSpacing.md) {
                ProgressView().controlSize(.large).tint(Color.dbPrimary)
                Text(recognizingTitle)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("正在用端侧视觉模型分析画面，并为你准备讲解…")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DBSpacing.lg)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在识别")
    }

    private var recognizingTitle: String {
        switch model.source {
        case .camera: "正在识别拍摄的画面…"
        case .photo: "正在识别这张照片…"
        case .file: "正在识别这张图片…"
        case .sample: "正在识别示例图…"
        }
    }

    // MARK: Loaded result

    private func resultView(_ result: RecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            identificationCard(result)
            explanationCard(result)
            if !result.relatedTopics.isEmpty {
                relatedCard(result)
            }
            actionBar(result)
        }
    }

    private func identificationCard(_ result: RecognitionResult) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(alignment: .top, spacing: DBSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                            .fill(result.category.tint.opacity(0.16))
                            .frame(width: 60, height: 60)
                        Image(systemName: result.category.symbolName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(result.category.tint)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text(result.name)
                            .font(.dbTitle)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        HStack(spacing: DBSpacing.sm) {
                            DBChip(result.category.displayName,
                                   systemImage: result.category.symbolName,
                                   tint: result.category.tint)
                            DBRouteBadge(.onDevice)
                        }
                    }
                    Spacer(minLength: 0)
                }

                confidenceRow(result)

                if !result.alternativeNames.isEmpty {
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text("也可能是")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextTertiary)
                        DBFlowLayout(spacing: DBSpacing.xs) {
                            ForEach(result.alternativeNames, id: \.self) { alt in
                                DBTag(alt, tint: result.category.tint)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("识别结果：\(result.name)，类别 \(result.category.displayName)，信心度 \(result.confidencePercent) %")
    }

    private func confidenceRow(_ result: RecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            HStack {
                Text("信心度 · \(result.confidenceLabel)")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                Spacer()
                Text("\(result.confidencePercent)%")
                    .font(.dbFootnote.monospacedDigit().weight(.semibold))
                    .foregroundStyle(result.category.tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dbSeparator)
                    Capsule()
                        .fill(result.category.tint)
                        .frame(width: max(8, geo.size.width * result.confidence))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
    }

    private func explanationCard(_ result: RecognitionResult) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("豆包讲一讲", systemImage: "text.bubble.fill")

                Text(result.explanation)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let fact = result.funFact {
                    HStack(alignment: .top, spacing: DBSpacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbAccent)
                        Text(fact)
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(DBSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dbAccentSoft, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                }
            }
        }
    }

    private func relatedCard(_ result: RecognitionResult) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("相关知识点", subtitle: "点一点，让豆包老师继续讲",
                                systemImage: "sparkles.rectangle.stack.fill")
                DBFlowLayout(spacing: DBSpacing.sm) {
                    ForEach(result.relatedTopics, id: \.self) { topic in
                        Button {
                            askTutor(about: topic, result: result)
                        } label: {
                            DBChip(topic, systemImage: "questionmark.bubble.fill",
                                   tint: result.category.tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("询问豆包老师")
                    }
                }
            }
        }
    }

    private func actionBar(_ result: RecognitionResult) -> some View {
        DBCard {
            VStack(spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.md) {
                    Button {
                        readAloud(result)
                    } label: {
                        Label(tts.isSpeaking ? "停止朗读" : "朗读讲解",
                              systemImage: tts.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(.db(.secondary))

                    Spacer(minLength: 0)
                }

                Button {
                    askTutor(about: defaultTutorPrompt(for: result), result: result)
                } label: {
                    Label("问豆包老师", systemImage: "graduationcap.fill")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
            }
        }
    }

    // MARK: Actions

    private func readAloud(_ result: RecognitionResult) {
        if tts.isSpeaking {
            tts.stop()
            return
        }
        let language = result.category == .word ? "en-US" : "zh-CN"
        let spoken: String
        if result.category == .word {
            spoken = result.name
        } else {
            spoken = "\(result.name)。\(result.explanation)"
        }
        tts.stop()
        tts.speak(spoken, language: language)
        HapticEngine.play(.light)
    }

    private func defaultTutorPrompt(for result: RecognitionResult) -> String {
        switch result.category {
        case .word:
            "请用简单的方式给小学生讲讲英文单词「\(result.name)」的意思、读法，并造一个例句。"
        case .math:
            "请围绕算式「\(result.name)」，给小学生讲讲解题思路和运算顺序，并写出每一步。"
        default:
            "请用小学生能懂的方式，给我讲讲「\(result.name)」是什么，有什么有趣的知识。"
        }
    }

    private func askTutor(about topic: String, result: RecognitionResult) {
        let prompt: String
        if topic.contains("？") || topic.contains("?") || topic.count > 12 {
            // Already a full question / instruction — pass through with context.
            prompt = "关于「\(result.name)」：\(topic)"
        } else {
            prompt = "关于「\(result.name)」，\(topic)"
        }
        tts.stop()
        router.present(.tutor(problemText: prompt,
                              subject: result.category.subject,
                              grade: grade))
        HapticEngine.play(.light)
    }

    // MARK: Idle tips

    private var tipsCard: some View {
        DBCard(fill: Color.dbPrimarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Label("拍清楚一点，识别更准", systemImage: "wand.and.stars")
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbPrimaryDeep)
                tip("把要识别的东西放在画面中间，离得近一些。")
                tip("光线明亮、背景简单，效果会更好。")
                tip("拍英文单词或算式时，让文字保持清晰、端正。")
            }
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.dbCaption)
                .foregroundStyle(Color.dbSecondary)
            Text(text)
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Image input

    private func loadSelectedPhoto() async {
        guard let photoSelection else { return }
        if let data = try? await photoSelection.loadTransferable(type: Data.self) {
            await model.recognize(imageData: data, source: .photo,
                                  intelligence: intelligence, grade: grade)
        }
        self.photoSelection = nil
    }

    #if os(macOS)
    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result,
              let data = Data.recognizeImage(from: url) else { return }
        Task { await model.recognize(imageData: data, source: .file,
                                     intelligence: intelligence, grade: grade) }
    }
    #endif
}

// MARK: - Preview

#Preview("识万物") {
    NavigationStack { RecognizeAnythingView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
