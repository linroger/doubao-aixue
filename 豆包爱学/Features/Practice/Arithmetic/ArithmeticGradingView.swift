//
//  ArithmeticGradingView.swift
//  豆包爱学 — Features/Practice/Arithmetic
//
//  口算批改 (F32 / F33). Entry point wired to `AppSheet.capture(.grade)` and
//  `ToolKind.gradeArithmetic`. Flow:
//    1. Input — 用示例作业 / 拍照(iOS)/相册 / 选择文件(macOS) / 手动增删改 ArithmeticItem.
//    2. 批改 — `intelligence.gradeArithmetic` (really computes).
//    3. Results — summary bar (correct/total + accuracy ring), per-item ✓/✗ overlay,
//       correctAnswer + 错因 for wrong items, 一键加入错题本, 再批一组 / 举一反三.
//
//  All ViewState branches handled; full Dark Mode via semantic Color.db*; both
//  platforms supported (camera is iOS-only, macOS imports a file or types).
//

import SwiftUI
import SwiftData
import PhotosUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct ArithmeticGradingView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query private var profiles: [LearnerProfile]

    @State private var model = ArithmeticGradingModel()
    @State private var photoSelection: PhotosPickerItem?
    @State private var isPreparingPhoto = false

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
                    inputSection
                case .loading:
                    DBStateView(kind: .loading, title: "正在批改…", message: "豆包正在一道道核对答案")
                        .frame(maxWidth: .infinity, minHeight: 320)
                case let .loaded(graded):
                    ArithmeticResultsView(
                        graded: graded,
                        model: model,
                        onAddToNotebook: addWrongToNotebook,
                        onPracticeMore: openPracticeMore,
                        onStartOver: model.startOver
                    )
                case let .empty(message):
                    DBStateView(
                        kind: .empty,
                        title: "还没有题目",
                        message: message,
                        systemImage: "square.and.pencil",
                        retry: { model.loadSample() }
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                    inputSection
                case let .error(message):
                    DBStateView(
                        kind: .error,
                        title: "出错了",
                        message: message,
                        retry: { Task { await model.grade(using: intelligence) } }
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                case let .offline(message):
                    DBStateView(kind: .offline, title: "离线模式", message: message)
                        .frame(maxWidth: .infinity, minHeight: 280)
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("口算批改")
        .onAppear(perform: prepareGradeOnce)
        .task(id: photoSelection) { await loadSelectedPhoto() }
        #if canImport(UIKit)
        .sheet(isPresented: $showCamera) {
            WorksheetCameraPicker { data in
                Task { await recognize(imageData: data) }
            }
            .ignoresSafeArea()
        }
        #endif
        #if os(macOS)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
            if case let .success(url) = result, let data = Data.worksheetImage(from: url) {
                Task { await recognize(imageData: data) }
            }
        }
        #endif
    }

    // MARK: - Input section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            introCard
            captureCard
            worksheetEditor
            gradeButton
        }
    }

    private var introCard: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                DBMascot(mood: .curious, size: 64)
                VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                    Text("口算批改")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("拍下整页口算，豆包逐题核对，标出 ✓ / ✗ 并讲清错因，错题一键收进错题本。")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                    DBChip(model.grade.displayName, systemImage: "graduationcap.fill", tint: .dbPrimary)
                        .padding(.top, DBSpacing.xxs)
                }
            }
        }
    }

    private var captureCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("添加作业", subtitle: "选择一种方式录入口算题", systemImage: "tray.and.arrow.down.fill")

                DBFlowLayout(spacing: DBSpacing.sm) {
                    #if canImport(UIKit)
                    captureButton(title: "拍照批改", systemImage: "camera.fill") {
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
                    captureButton(title: "选择图片", systemImage: "folder.fill") {
                        showFileImporter = true
                    }
                    #endif

                    captureButton(title: "用示例作业", systemImage: "sparkles") {
                        model.loadSample()
                        HapticEngine.play(.selection)
                    }

                    captureButton(title: "手动添加", systemImage: "plus.circle.fill") {
                        model.addBlankItem()
                        HapticEngine.play(.selection)
                    }
                }

                if isPreparingPhoto {
                    HStack(spacing: DBSpacing.xs) {
                        ProgressView()
                        Text("正在识别题目…")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                }

                #if os(macOS)
                Text("Mac 端不支持相机，可选择图片文件或手动输入题目。")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextTertiary)
                #endif
            }
        }
    }

    private func captureButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            captureChipLabel(title: title, systemImage: systemImage)
        }
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

    // MARK: Worksheet editor

    @ViewBuilder private var worksheetEditor: some View {
        if model.items.isEmpty {
            DBCard(fill: .dbSurface) {
                VStack(spacing: DBSpacing.sm) {
                    Image(systemName: "list.number")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.dbTextTertiary)
                    Text("还没有题目")
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("先「用示例作业」或「手动添加」一道口算题吧～")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DBSpacing.md)
            }
        } else {
            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    DBSectionHeader("题目列表", subtitle: "共 \(model.items.count) 道，可编辑算式与作答", systemImage: "pencil.and.list.clipboard") {
                        Button("清空") { model.clearAll() }
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbError)
                    }

                    ForEach($model.items) { $item in
                        ArithmeticItemEditorRow(item: $item) {
                            if let index = model.items.firstIndex(where: { $0.id == item.id }) {
                                model.removeItems(at: IndexSet(integer: index))
                            }
                        }
                        if item.id != model.items.last?.id {
                            Divider().overlay(Color.dbSeparator)
                        }
                    }

                    Button {
                        model.addBlankItem()
                        HapticEngine.play(.selection)
                    } label: {
                        Label("再加一道", systemImage: "plus")
                            .font(.dbSubheadline)
                    }
                    .buttonStyle(.db(.ghost))
                    .padding(.top, DBSpacing.xxs)
                }
            }
        }
    }

    private var gradeButton: some View {
        Button {
            HapticEngine.play(.light)
            Task { await model.grade(using: intelligence) }
        } label: {
            Label("开始批改", systemImage: "checkmark.seal.fill")
        }
        .buttonStyle(.db(.primary, fullWidth: true))
        .disabled(!model.canGrade)
        .opacity(model.canGrade ? 1 : 0.5)
    }

    // MARK: - Actions

    private func prepareGradeOnce() {
        // Seed the request grade from the learner profile (once), so messaging matches.
        if case .idle = model.state, model.items.isEmpty {
            if let grade = profiles.first?.grade {
                model.grade = grade
            }
        }
    }

    private func recognize(imageData: Data) async {
        isPreparingPhoto = true
        await model.recognize(imageData: imageData, using: ocr)
        isPreparingPhoto = false
        HapticEngine.play(.selection)
    }

    private func loadSelectedPhoto() async {
        guard let photoSelection else { return }
        isPreparingPhoto = true
        defer { isPreparingPhoto = false; self.photoSelection = nil }
        if let data = try? await photoSelection.loadTransferable(type: Data.self) {
            await model.recognize(imageData: data, using: ocr)
            HapticEngine.play(.selection)
        } else {
            // Couldn't read the picked photo (corrupt / permission) — give feedback
            // instead of silently doing nothing.
            HapticEngine.play(.warning)
        }
    }

    private func addWrongToNotebook() {
        let count = model.addWrongItemsToNotebook(context: modelContext)
        if count > 0 { HapticEngine.play(.success) }
    }

    /// 举一反三 / 再练一组: hand the wrong (or first) expression to the tutor for guided practice.
    private func openPracticeMore() {
        let seed = model.wrongItems.first?.expression
            ?? model.graded?.items.first?.expression
            ?? "口算练习"
        HapticEngine.play(.light)
        router.present(.tutor(problemText: "请围绕「\(seed)」出 3 道同类口算题，并讲讲思路。",
                              subject: .math,
                              grade: model.grade))
    }
}

// MARK: - Editable item row

private struct ArithmeticItemEditorRow: View {
    @Binding var item: ArithmeticItem
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: DBSpacing.sm) {
            TextField("算式，如 12 + 7", text: $item.expression)
                .font(.dbMonoBody)
                .textFieldStyle(.plain)
                .padding(.horizontal, DBSpacing.sm)
                .padding(.vertical, DBSpacing.xs)
                .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                #if os(iOS)
                .autocorrectionDisabled()
                #endif

            Text("=")
                .font(.dbBodyEmph)
                .foregroundStyle(Color.dbTextSecondary)

            TextField("作答", text: $item.studentAnswer)
                .font(.dbMonoBody)
                .textFieldStyle(.plain)
                .frame(width: 64)
                .padding(.horizontal, DBSpacing.sm)
                .padding(.vertical, DBSpacing.xs)
                .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                #endif

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除这道题")
        }
        .padding(.vertical, DBSpacing.xxs)
    }
}

// MARK: - Preview

#Preview("口算批改") {
    NavigationStack {
        ArithmeticGradingView()
    }
    .modelContainer(ModelContainerFactory.make(inMemory: true))
    .environment(AppRouter())
    .environment(TTSService())
}
