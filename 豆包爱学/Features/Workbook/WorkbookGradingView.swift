//
//  WorkbookGradingView.swift
//  豆包爱学 — Features/Workbook
//
//  作业批改 (workbook grading): photograph / pick / upload a workbook page and the AI
//  grades every question, rendering a structured `GradedWorkbook` via `WorkbookResultContent`.
//  Three acquisition paths exactly as the product requires — 拍照 (iOS camera), 从相册选
//  (Photos), 上传文件 (file importer, the primary path on macOS) — plus 试试示例. Each
//  grading is persisted to 批改历史 (WorkbookHistoryView, reachable from the toolbar).
//
//  Wired to `ToolKind.gradeWorkbook` via the no-argument `init()`.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct WorkbookGradingView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var profiles: [LearnerProfile]

    @State private var model = WorkbookGradingModel()
    @State private var photoSelection: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var didConfigure = false
    #if os(iOS)
    @State private var showCamera = false
    #endif

    init() {}

    private var profile: LearnerProfile? { profiles.first }
    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                heroCard
                captureCard
                resultSection
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("作业批改")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    WorkbookHistoryView()
                } label: {
                    Label("批改历史", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .task(id: photoSelection) { await loadSelectedPhoto() }
        .onAppear(perform: configureIfNeeded)
        .onChange(of: profile?.grade) { _, g in if let g { model.grade = g } }
        .onChange(of: profile?.learnModeEnabled) { _, on in if let on { model.learnMode = on } }
        #if os(iOS)
        .sheet(isPresented: $showCamera) {
            WorkbookCameraPicker { data in
                model.setImage(data, source: .camera)
            }
            .ignoresSafeArea()
        }
        #endif
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.image, .png, .jpeg, .heic, .tiff, .pdf]) { result in
            handleFileImport(result)
        }
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        model.grade = profile?.grade ?? .g5
        model.learnMode = profile?.learnModeEnabled ?? true
    }

    // MARK: Hero

    private var heroCard: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                DBMascot(mood: model.isWorking ? .thinking : .curious, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("拍一页作业，我来逐题批改")
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("数学、语文、英语……各科都行。判对错、讲错因、收错题，一步到位。")
                        .font(.dbCaption)
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
                DBSectionHeader("上传作业", subtitle: "拍照、相册或文件，任选一种", systemImage: "doc.viewfinder")

                if let preview = model.previewImage {
                    ZStack {
                        preview
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
                        if model.isWorking {
                            ZStack {
                                RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous).fill(.ultraThinMaterial)
                                VStack(spacing: DBSpacing.sm) {
                                    ProgressView().controlSize(.large).tint(Color.dbPrimary)
                                    Text("正在批改作业…").font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                                }
                            }
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous).strokeBorder(Color.dbSeparator, lineWidth: 1))
                }

                DBFlowLayout(spacing: DBSpacing.sm) {
                    #if os(iOS)
                    captureChip("拍照", systemImage: "camera.fill") {
                        showCamera = true; HapticEngine.play(.selection)
                    }
                    #endif
                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Label("从相册选", systemImage: "photo.on.rectangle.angled")
                            .font(.dbSubheadline)
                            .foregroundStyle(Color.dbPrimary)
                            .padding(.horizontal, DBSpacing.md)
                            .padding(.vertical, DBSpacing.sm)
                            .background(Color.dbPrimary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    captureChip("上传文件", systemImage: "folder.fill") {
                        showFileImporter = true
                    }
                    captureChip("试试示例", systemImage: "sparkles") {
                        Task { await model.runSample(context: modelContext) }
                        HapticEngine.play(.selection)
                    }
                    if model.hasImage {
                        captureChip("换一张", systemImage: "arrow.counterclockwise") {
                            model.reset()
                        }
                    }
                }

                subjectHintPicker

                if model.hasImage && !model.isWorking {
                    Button {
                        Task { await model.grade(using: intelligence, ocr: ocr, context: modelContext) }
                    } label: {
                        Label("开始批改", systemImage: "checkmark.seal.fill")
                    }
                    .buttonStyle(.db(.primary, fullWidth: true))
                }

                #if os(macOS)
                Text("Mac 端可从相册或文件选择一张作业图片，或点「试试示例」。")
                    .font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                #endif
            }
        }
    }

    private var subjectHintPicker: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            Text("学科（可选）").font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.sm) {
                    Button { model.subjectHint = nil; HapticEngine.play(.selection) } label: {
                        DBChip("自动识别", systemImage: "wand.and.stars", tint: .dbSecondary, isSelected: model.subjectHint == nil)
                    }
                    .buttonStyle(.plain)
                    ForEach(WorkbookGradingModel.selectableSubjects) { subject in
                        Button {
                            model.subjectHint = (model.subjectHint == subject ? nil : subject)
                            HapticEngine.play(.selection)
                        } label: {
                            DBSubjectChip(subject, isSelected: model.subjectHint == subject)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func captureChip(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(title, systemImage: systemImage) }
            .buttonStyle(.plain)
    }

    private func chipLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.dbSubheadline)
            .foregroundStyle(Color.dbPrimaryDeep)
            .padding(.horizontal, DBSpacing.md)
            .padding(.vertical, DBSpacing.sm)
            .background(Color.dbPrimarySoft, in: Capsule())
    }

    // MARK: Result (ViewState)

    @ViewBuilder
    private var resultSection: some View {
        switch model.state {
        case .idle:
            tipsCard
        case .loading:
            if !model.hasImage {
                DBStateView(kind: .loading, title: "正在批改…").frame(minHeight: 200)
            }
        case .empty(let message):
            DBStateView(kind: .empty, title: "没识别到题目", message: message)
                .frame(maxWidth: .infinity).frame(minHeight: 200)
        case .error(let message):
            DBStateView(kind: .error, title: "批改出错了", message: message, retry: {
                Task { await model.grade(using: intelligence, ocr: ocr, context: modelContext) }
            })
            .frame(maxWidth: .infinity).frame(minHeight: 200)
        case .offline(let message):
            DBStateView(kind: .offline, title: "离线模式", message: message)
                .frame(maxWidth: .infinity).frame(minHeight: 200)
        case .loaded(let workbook):
            WorkbookResultContent(workbook: workbook, imageData: model.imageData)
        }
    }

    private var tipsCard: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Label("拍清楚一点，批改更准", systemImage: "checkmark.circle.fill")
                    .font(.dbBodyEmph).foregroundStyle(Color.dbPrimaryDeep)
                tip("把整页作业放进画面，光线均匀、不要反光。")
                tip("题目和答案都拍清楚，手写字迹尽量端正。")
                tip("选择对应学科会更准；不选则自动识别。")
            }
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: "checkmark.circle.fill").font(.dbCaption).foregroundStyle(Color.dbSecondary)
            Text(text).font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Image input

    private func loadSelectedPhoto() async {
        guard let photoSelection else { return }
        if let data = try? await photoSelection.loadTransferable(type: Data.self) {
            model.setImage(data, source: .album)
        } else {
            // Couldn't read the picked photo — let the learner know to retry.
            HapticEngine.play(.warning)
        }
        self.photoSelection = nil
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result, let data = Data.workbookImage(from: url) else {
            HapticEngine.play(.warning)
            return
        }
        model.setImage(data, source: .document)
    }
}

// MARK: - Preview

#Preview("作业批改") {
    NavigationStack { WorkbookGradingView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
