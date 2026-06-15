//
//  DictationSessionView.swift
//  豆包爱学 — Features/Practice/Dictation
//
//  The three-phase 听写 runner UI built on DictationSessionModel: 念词 (TTS controls),
//  默写 (typed + 手写 on iOS), and 批改结果 (accuracy ring + per-word ✓/✗ + 重测错词).
//

import SwiftUI
import SwiftData

struct DictationSessionView: View {
    @Bindable var model: DictationSessionModel
    let listName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                switch model.phase {
                case .reading:
                    readingPhase
                case .writing:
                    DictationWritingView(model: model)
                case .grading:
                    gradingPhase
                case .result:
                    DictationResultView(model: model)
                }
            }
            .padding(DBSpacing.screenInset)
            .animation(.snappy, value: model.phase)
        }
        .background(Color.dbBackground)
        .onDisappear { model.stopAutoPlay() }
    }

    // MARK: 念词 phase

    private var readingPhase: some View {
        VStack(spacing: DBSpacing.lg) {
            if model.isRetryRound {
                DBChip("重测错词 · 共 \(model.totalThisRound) 个", systemImage: "arrow.triangle.2.circlepath",
                       tint: .dbWarning, isSelected: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            progressHeader

            DBCard {
                VStack(spacing: DBSpacing.md) {
                    DBMascot(mood: model.isAutoPlaying ? .happy : .thinking, size: 72)
                    Text(model.isAutoPlaying ? "认真听，把字写在纸上或下一步输入" : "点下面的喇叭，老师就念给你听")
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        model.speakCurrent()
                    } label: {
                        Label("念第 \(model.currentIndex + 1) 个", systemImage: "speaker.wave.3.fill")
                    }
                    .buttonStyle(.db(.primary, fullWidth: true))

                    HStack(spacing: DBSpacing.md) {
                        Button {
                            model.goPrevious()
                        } label: {
                            Label("上一个", systemImage: "backward.fill")
                        }
                        .buttonStyle(.db(.secondary))
                        .disabled(model.isFirstEntry)

                        Button {
                            model.toggleAutoPlay()
                        } label: {
                            Label(model.isAutoPlaying ? "暂停" : "自动播放",
                                  systemImage: model.isAutoPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.db(.secondary))

                        Button {
                            model.goNext()
                        } label: {
                            Label("下一个", systemImage: "forward.fill")
                        }
                        .buttonStyle(.db(.secondary))
                        .disabled(model.isLastEntry)
                    }
                }
            }

            controlsCard

            Button {
                model.beginWriting()
            } label: {
                Label("听好了，去默写", systemImage: "pencil.and.outline")
            }
            .buttonStyle(.db(.primary, fullWidth: true))
        }
    }

    private var progressHeader: some View {
        HStack {
            Text("第 \(min(model.currentIndex + 1, model.totalThisRound)) / \(model.totalThisRound) 个")
                .font(.dbHeadline)
                .foregroundStyle(Color.dbTextPrimary)
            Spacer()
            DBTag(model.language == .english ? "英语听写" : "语文听写",
                  tint: DBSubjectColor.color(for: model.language))
        }
    }

    private var controlsCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("朗读设置", systemImage: "slider.horizontal.3")

                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("语速").font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                    Picker("语速", selection: $model.speed) {
                        ForEach(DictationSessionModel.Speed.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    HStack {
                        Text("每个词间隔").font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                        Spacer()
                        Text("\(Int(model.gapSeconds)) 秒").font(.dbFootnote).foregroundStyle(Color.dbTextPrimary)
                    }
                    Slider(value: $model.gapSeconds, in: 1...8, step: 1)
                        .tint(.dbPrimary)
                }

                Stepper(value: $model.repeatCount, in: 1...3) {
                    HStack {
                        Text("重复次数").font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                        Spacer()
                        Text("\(model.repeatCount) 遍").font(.dbFootnote).foregroundStyle(Color.dbTextPrimary)
                    }
                }

                Toggle(isOn: $model.autoAdvance) {
                    Text("自动播放下一个").font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                }
                .tint(.dbPrimary)
            }
        }
    }

    // MARK: 批改中 phase

    private var gradingPhase: some View {
        VStack(spacing: DBSpacing.lg) {
            DBStateView(kind: .loading, title: "豆包老师批改中…",
                        message: "正在一个一个对照你写的字。")
                .frame(maxWidth: .infinity, minHeight: 280)
        }
    }
}

#Preview("念词") {
    DictationSessionPreview()
}

/// Builds a real session model from the seeded preview container so the runner
/// can be previewed end-to-end.
private struct DictationSessionPreview: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(TTSService.self) private var tts
    @Environment(\.modelContext) private var context
    @State private var model: DictationSessionModel?

    var body: some View {
        Group {
            if let model {
                NavigationStack { DictationSessionView(model: model, listName: model.listName) }
            } else {
                DBStateView(kind: .loading, title: "加载中")
                    .task { build() }
            }
        }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
    }

    private func build() {
        guard model == nil,
              let list = try? context.fetch(FetchDescriptor<DictationList>()).first else { return }
        model = DictationSessionModel(list: list, intelligence: intelligence,
                                      ocr: ocr, tts: tts, modelContext: context)
    }
}
