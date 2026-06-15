//
//  DictationWritingView.swift
//  豆包爱学 — Features/Practice/Dictation
//
//  默写 phase: one row per word with a typed field. On iOS each row also offers a
//  手写 sheet (PencilKit) whose strokes run through on-device OCR to fill the field.
//  macOS keeps typing only. "再听一遍" returns to the read-aloud phase; "提交批改"
//  hands the answers to intelligence.gradeDictation.
//

import SwiftUI
import SwiftData

struct DictationWritingView: View {
    @Bindable var model: DictationSessionModel

    #if os(iOS)
    @State private var handwritingEntry: DictationEntry?
    #endif

    private var filledCount: Int {
        model.activeEntries.filter { !model.answer(for: $0).trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            header

            ForEach(Array(model.activeEntries.enumerated()), id: \.element.id) { index, entry in
                DictationWriteRow(
                    index: index + 1,
                    text: bindingFor(entry),
                    language: model.language,
                    onHandwrite: handwriteAction(for: entry)
                )
            }

            if let err = model.gradeError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbError)
            }

            VStack(spacing: DBSpacing.sm) {
                Button {
                    Task { await model.submitForGrading() }
                } label: {
                    Label("提交批改", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(.db(.primary, fullWidth: true))

                Button {
                    model.backToReading()
                } label: {
                    Label("再听一遍", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.db(.ghost, fullWidth: true))
            }
        }
        #if os(iOS)
        .sheet(item: $handwritingEntry) { entry in
            DictationHandwritingSheet(entry: entry) { imageData in
                Task { await model.recognizeHandwriting(imageData, for: entry) }
            }
        }
        #endif
    }

    private var header: some View {
        DBCard {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: .curious, size: 52)
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text(model.isRetryRound ? "把刚才错的字再写一遍" : "凭记忆把每个词写出来")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("已写 \(filledCount) / \(model.totalThisRound) 个")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func bindingFor(_ entry: DictationEntry) -> Binding<String> {
        Binding(
            get: { model.answers[entry.id] ?? "" },
            set: { model.answers[entry.id] = $0 }
        )
    }

    /// Returns a non-nil hand-writing closure only on iOS (PencilKit-backed).
    private func handwriteAction(for entry: DictationEntry) -> (() -> Void)? {
        #if os(iOS)
        return { handwritingEntry = entry }
        #else
        return nil
        #endif
    }
}

// MARK: - One word row

private struct DictationWriteRow: View {
    let index: Int
    @Binding var text: String
    let language: Subject
    let onHandwrite: (() -> Void)?

    var body: some View {
        DBCard {
            HStack(spacing: DBSpacing.md) {
                Text("\(index)")
                    .font(.dbHeadline)
                    .foregroundStyle(Color.dbPrimary)
                    .frame(width: 28)

                TextField(language == .english ? "type the word" : "写出这个词",
                          text: $text)
                    .font(.dbBody)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .textInputAutocapitalization(language == .english ? .never : .sentences)
                    .autocorrectionDisabled(language != .english)
                    #endif

                if let onHandwrite {
                    Button(action: onHandwrite) {
                        Image(systemName: "hand.draw")
                            .font(.dbBody)
                            .foregroundStyle(Color.dbPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("手写输入")
                }
            }
        }
    }
}

#Preview {
    DictationWritingPreview()
}

private struct DictationWritingPreview: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(TTSService.self) private var tts
    @Environment(\.modelContext) private var context
    @State private var model: DictationSessionModel?

    var body: some View {
        ScrollView {
            if let model {
                DictationWritingView(model: model).padding(DBSpacing.screenInset)
            } else {
                DBStateView(kind: .loading, title: "加载中").task { build() }
            }
        }
        .background(Color.dbBackground)
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
    }

    private func build() {
        guard model == nil,
              let list = try? context.fetch(FetchDescriptor<DictationList>()).first else { return }
        let m = DictationSessionModel(list: list, intelligence: intelligence,
                                      ocr: ocr, tts: tts, modelContext: context)
        m.beginWriting()
        model = m
    }
}
