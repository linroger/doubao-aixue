//
//  DictationResultView.swift
//  豆包爱学 — Features/Practice/Dictation
//
//  批改结果: accuracy ring + 鼓励语 + per-word ✓/✗ list (showing the child's answer
//  next to the correct one for wrong words) + 重测错词 / 重新听写. Wrong words have
//  already been folded into the 错题本 and a DictationResult persisted by the model.
//

import SwiftUI
import SwiftData

struct DictationResultView: View {
    @Bindable var model: DictationSessionModel

    private var grading: DictationGrading? { model.grading }

    private var accuracy: Double {
        guard let grading, grading.total > 0 else { return 0 }
        return Double(grading.correct) / Double(grading.total)
    }

    var body: some View {
        if let grading {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                scoreCard(grading)
                routeBadge(grading)
                wordList
                actions
            }
        } else {
            DBStateView(kind: .error, title: "暂时没有批改结果",
                        message: "回到默写页重新提交一次吧。")
        }
    }

    private func scoreCard(_ grading: DictationGrading) -> some View {
        DBCard {
            VStack(spacing: DBSpacing.md) {
                DBProgressRing(progress: accuracy,
                               lineWidth: 12,
                               tint: ringTint,
                               label: "\(Int((accuracy * 100).rounded()))%")
                    .frame(width: 132, height: 132)

                Text(headline(for: accuracy))
                    .font(.dbTitle3)
                    .foregroundStyle(Color.dbTextPrimary)

                Text("写对 \(grading.correct) / \(grading.total) 个" +
                     (model.isRetryRound ? " · 重测错词" : ""))
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func routeBadge(_ grading: DictationGrading) -> some View {
        HStack {
            DBRouteBadge(grading.route)
            Spacer()
            Text("错的字已收进错题本")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
        }
    }

    private var wordList: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("逐词批改", systemImage: "list.bullet.clipboard")
            ForEach(model.resultRows) { row in
                DictationResultRow(row: row, language: model.language)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: DBSpacing.sm) {
            if !model.wrongEntries.isEmpty {
                Button {
                    model.retryWrongWords()
                } label: {
                    Label("重测错词 (\(model.wrongEntries.count) 个)", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
            } else {
                Label("全部正确，太棒啦！", systemImage: "star.fill")
                    .font(.dbHeadline)
                    .foregroundStyle(Color.dbSuccess)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DBSpacing.sm)
            }

            Button {
                model.restartAll()
            } label: {
                Label("重新听写整张表", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.db(.secondary, fullWidth: true))
        }
    }

    // MARK: Copy / styling

    private var ringTint: Color {
        switch accuracy {
        case 0.9...: .dbSuccess
        case 0.6..<0.9: .dbPrimary
        default: .dbWarning
        }
    }

    private func headline(for accuracy: Double) -> String {
        switch accuracy {
        case 1: "满分！全部写对啦"
        case 0.8..<1: "很棒，只差一点点"
        case 0.5..<0.8: "不错，把错词再练练"
        default: "别灰心，我们重测错词"
        }
    }
}

// MARK: - Per-word row

private struct DictationResultRow: View {
    let row: DictationSessionModel.ResultRow
    let language: Subject

    var body: some View {
        DBCard {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                Image(systemName: row.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.dbTitle3)
                    .foregroundStyle(row.isCorrect ? Color.dbSuccess : Color.dbError)

                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    HStack(spacing: DBSpacing.sm) {
                        Text(row.expected)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                        if !row.reading.isEmpty {
                            Text(row.reading)
                                .font(.dbCaption)
                                .foregroundStyle(Color.dbTextTertiary)
                        }
                    }
                    if !row.isCorrect {
                        Text(row.written.isEmpty ? "你没有写" : "你写的：\(row.written)")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbError)
                    }
                    if !row.meaning.isEmpty {
                        Text(row.meaning)
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    DictationResultPreview()
}

private struct DictationResultPreview: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(TTSService.self) private var tts
    @Environment(\.modelContext) private var context
    @State private var model: DictationSessionModel?

    var body: some View {
        ScrollView {
            if let model {
                DictationResultView(model: model).padding(DBSpacing.screenInset)
            } else {
                DBStateView(kind: .loading, title: "加载中").task { await build() }
            }
        }
        .background(Color.dbBackground)
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
    }

    private func build() async {
        guard model == nil,
              let list = try? context.fetch(FetchDescriptor<DictationList>()).first else { return }
        let m = DictationSessionModel(list: list, intelligence: intelligence,
                                      ocr: ocr, tts: tts, modelContext: context)
        m.beginWriting()
        // Pre-fill a couple answers (one wrong) so the result has texture.
        for (i, entry) in m.activeEntries.enumerated() {
            m.answers[entry.id] = i == 0 ? "错字" : entry.text
        }
        await m.submitForGrading()
        model = m
    }
}
