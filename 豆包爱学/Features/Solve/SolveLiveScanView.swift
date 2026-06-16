//
//  SolveLiveScanView.swift
//  豆包爱学 — Features/Solve
//
//  实时扫题: a top-level view that hosts the VisionKit live text scanner on iOS so a
//  learner can hover the camera over a problem and either tap a single line
//  (tap-to-pick-region) or capture every recognized line at once. The captured text is
//  shown in an editable review card and then handed to the existing `SolveResultView`
//  pipeline — identical to the typed/photo path, so the solve experience is unchanged.
//
//  Platform behavior:
//  • iOS with a capable device → live `DataScannerViewController` scanner.
//  • iOS without support / macOS → graceful guidance directing the learner to the
//    standard 拍照解题 capture sheet (camera/import/typed), which already covers them.
//
//  Pushed into the shell's NavigationStack, so this view sets a title and never wraps
//  its own stack. It exposes a no-arg `init()` for the integrator to wire via a route.
//

import SwiftUI
import SwiftData

struct SolveLiveScanView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [LearnerProfile]

    @State private var model = SolveLiveScanModel()

    init() {}

    private var profile: LearnerProfile? { profiles.first }

    var body: some View {
        Group {
            if SolveLiveScanAvailability.isSupported {
                scannerLayout
            } else {
                unsupportedLayout
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("实时扫题")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(isPresented: $model.showResult) {
            SolveResultView(
                recognizedText: model.confirmedText,
                subject: model.subject,
                grade: profile?.grade ?? .g5,
                source: .camera,
                imageData: nil,
                learnModeEnabled: profile?.learnModeEnabled ?? true
            )
        }
    }

    // MARK: Scanner layout (iOS, supported)

    @ViewBuilder private var scannerLayout: some View {
        VStack(spacing: 0) {
            scannerPane
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous)
                        .strokeBorder(Color.dbSeparator, lineWidth: 1)
                )
                .overlay(alignment: .top) { scannerHint }
                .padding(DBSpacing.screenInset)

            ScrollView {
                VStack(spacing: DBSpacing.lg) {
                    reviewSection
                }
                .padding(.horizontal, DBSpacing.screenInset)
                .padding(.bottom, DBSpacing.xl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private var scannerPane: some View {
        #if os(iOS) && canImport(VisionKit)
        if #available(iOS 16.0, *) {
            SolveDataScanner(
                onTapItem: { text in
                    model.captureTapped(text)
                    HapticEngine.play(.success)
                },
                onRecognizedTextChanged: { lines in
                    model.updateLiveLines(lines)
                },
                captureAllToken: $model.captureAllToken
            )
            .accessibilityLabel("实时取景，把题目对准取景框")
            .accessibilityHint("识别到题目后，点按高亮文字选取该行，或点下方按钮识别全部")
        } else {
            scannerPlaceholder
        }
        #else
        scannerPlaceholder
        #endif
    }

    private var scannerPlaceholder: some View {
        ZStack {
            Color.dbSurfaceRaised
            DBMascot(mood: .curious, size: 64)
        }
    }

    private var scannerHint: some View {
        HStack(spacing: DBSpacing.xs) {
            Image(systemName: "viewfinder")
            Text(model.liveLineCount > 0
                 ? "识别到 \(model.liveLineCount) 行 · 点高亮文字选这一行"
                 : "把题目放进取景框，靠近一点更清晰")
        }
        .font(.dbCaption.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, DBSpacing.md)
        .padding(.vertical, DBSpacing.sm)
        .background(.black.opacity(0.42), in: Capsule())
        .padding(.top, DBSpacing.md)
        .accessibilityElement(children: .combine)
    }

    // MARK: Review section (captured text → editable → solve)

    @ViewBuilder private var reviewSection: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack {
                    Label("识别到的题目", systemImage: "doc.text.viewfinder")
                        .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                    Spacer()
                    if model.hasCapturedText {
                        Button("清空") { model.clearCaptured() }
                            .font(.dbFootnote.weight(.medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.dbPrimary)
                    }
                }

                if model.hasCapturedText {
                    TextEditor(text: $model.confirmedText)
                        .font(.dbBody)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(DBSpacing.sm)
                        .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                        .accessibilityLabel("识别到的题目，可编辑")
                    subjectPicker
                    Text("识别可能有误？校对后再解答，避免答错。")
                        .font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                } else {
                    Text("还没有选取文字。把镜头对准题目，点高亮的文字就能把它放进来。")
                        .font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                }
            }
        }

        captureAllButton

        Button {
            model.start()
        } label: {
            Label("开始解答", systemImage: "wand.and.stars")
        }
        .buttonStyle(.db(.primary, fullWidth: true))
        .disabled(!model.canSolve)
    }

    private var captureAllButton: some View {
        Button {
            model.captureAll()
            HapticEngine.play(.light)
        } label: {
            Label("识别全部文字", systemImage: "text.viewfinder")
        }
        .buttonStyle(.db(.secondary, fullWidth: true))
        .disabled(model.liveLineCount == 0)
        .accessibilityHint("把当前取景框里识别到的所有文字加入题目")
    }

    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            Text("学科").font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.sm) {
                    ForEach(SolveLiveScanModel.selectableSubjects) { subject in
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

    // MARK: Unsupported layout (macOS / older iOS)

    private var unsupportedLayout: some View {
        ScrollView {
            VStack(spacing: DBSpacing.lg) {
                DBCard(fill: .dbPrimarySoft, elevation: .none) {
                    HStack(spacing: DBSpacing.md) {
                        DBMascot(mood: .curious, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("这台设备暂不支持实时扫题")
                                .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                            Text("没关系，用拍照、导入图片或手动输入一样能解题。")
                                .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }

                DBStateView(
                    kind: .empty,
                    title: "改用拍照解题",
                    message: "在拍照解题里可以拍照、从相册或文件导入、也可以直接输入题目。",
                    systemImage: "camera.viewfinder"
                )

                Button {
                    let isRegular = sizeClass != .compact
                    router.openTool(.solve, regular: isRegular)
                } label: {
                    Label("打开拍照解题", systemImage: "camera.fill")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Model

@MainActor
@Observable
final class SolveLiveScanModel {
    var confirmedText: String = ""
    var subject: Subject = .math
    var showResult = false

    /// One-shot token bumped to ask the scanner to emit all recognized lines.
    var captureAllToken = 0

    private var liveLines: [String] = []

    static let selectableSubjects: [Subject] = [
        .math, .physics, .chemistry, .biology, .chinese, .english, .science, .general
    ]

    var liveLineCount: Int { liveLines.count }

    var hasCapturedText: Bool {
        !confirmedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSolve: Bool { hasCapturedText }

    /// Track the latest set of recognized lines so "识别全部" has something to capture.
    func updateLiveLines(_ lines: [String]) {
        liveLines = lines
    }

    /// Tap-to-pick-region: append exactly the tapped line.
    func captureTapped(_ text: String) {
        append(text)
    }

    /// Bump the token so the representable emits the current full recognition, then it
    /// is folded into the captured text via `applyCaptureAll`.
    func captureAll() {
        let joined = liveLines.joined(separator: "\n")
        append(joined)
        captureAllToken &+= 1
    }

    private func append(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if confirmedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            confirmedText = trimmed
        } else {
            confirmedText += "\n" + trimmed
        }
        subject = MockContent.inferSubject(from: confirmedText)
    }

    func clearCaptured() {
        confirmedText = ""
    }

    func start() {
        guard canSolve else { return }
        HapticEngine.play(.light)
        showResult = true
    }
}

// MARK: - Preview

#Preview("实时扫题") {
    NavigationStack {
        SolveLiveScanView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
