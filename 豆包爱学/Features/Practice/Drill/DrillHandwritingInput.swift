//
//  DrillHandwritingInput.swift
//  豆包爱学 — Features/Practice/Drill
//
//  The answer input surface for the drill runner. On iOS it offers a PencilKit
//  handwriting canvas (write the answer with finger/Pencil) that recognizes the
//  strokes via the OCR service, plus a typed field. On macOS (no PencilKit) it
//  degrades cleanly to the typed field only. Both paths write the same `answer`
//  binding, so the runner never needs to know which input was used.
//

import SwiftUI

#if canImport(UIKit)
import PencilKit
#endif

// MARK: - Public input view

/// Combined typed + (iOS) handwriting input for one answer.
struct DrillAnswerInput: View {
    @Binding var answer: String
    var subject: Subject
    var isLocked: Bool
    var onSubmit: () -> Void

    #if canImport(UIKit)
    @Environment(\.ocr) private var ocr
    @State private var canvas = PKCanvasView()
    @State private var usingHandwriting = false
    @State private var recognizing = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            #if canImport(UIKit)
            inputModePicker
            if usingHandwriting {
                handwritingArea
            } else {
                typedField
            }
            #else
            typedField
            #endif
        }
    }

    // MARK: Typed field (both platforms)

    private var typedField: some View {
        HStack(spacing: DBSpacing.sm) {
            TextField("在这里写出你的答案", text: $answer)
                .font(.dbBodyEmph)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.dbTextPrimary)
                .disabled(isLocked)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                #if canImport(UIKit)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
            if !answer.isEmpty && !isLocked {
                Button {
                    answer = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.dbTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空答案")
            }
        }
        .padding(DBSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                .fill(Color.dbSurfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                .strokeBorder(Color.dbSeparator, lineWidth: 1)
        )
    }

    #if canImport(UIKit)

    // MARK: Handwriting (iOS / iPadOS)

    private var inputModePicker: some View {
        Picker("输入方式", selection: $usingHandwriting) {
            Label("键盘", systemImage: "keyboard").tag(false)
            Label("手写", systemImage: "pencil.tip").tag(true)
        }
        .pickerStyle(.segmented)
        .disabled(isLocked)
    }

    private var handwritingArea: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            ZStack(alignment: .topLeading) {
                DrillCanvasRepresentable(canvas: canvas, isLocked: isLocked)
                    .frame(height: 150)
                    .background(Color.dbSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                            .strokeBorder(Color.dbSeparator, lineWidth: 1)
                    )
                if canvas.drawing.bounds.isEmpty {
                    Text("用手指或 Apple Pencil 在此书写答案")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextTertiary)
                        .padding(DBSpacing.md)
                        .allowsHitTesting(false)
                }
            }

            // The recognized answer is editable so the learner can fix OCR slips.
            if !answer.isEmpty {
                HStack(spacing: DBSpacing.xs) {
                    Image(systemName: "text.viewfinder")
                        .foregroundStyle(Color.dbPrimary)
                    Text("识别结果：\(answer)")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                }
            }

            HStack(spacing: DBSpacing.sm) {
                Button {
                    recognizeStrokes()
                } label: {
                    Label(recognizing ? "识别中…" : "识别手写", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.db(.secondary, fullWidth: true))
                .disabled(isLocked || recognizing)

                Button {
                    canvas.drawing = PKDrawing()
                    answer = ""
                } label: {
                    Label("清除", systemImage: "eraser")
                }
                .buttonStyle(.db(.ghost))
                .disabled(isLocked)
            }
        }
    }

    private func recognizeStrokes() {
        guard !recognizing else { return }
        let bounds = canvas.drawing.bounds
        guard !bounds.isEmpty else { return }
        recognizing = true
        let image = canvas.drawing.image(from: bounds, scale: 2)
        let data = image.pngData()
        Task { @MainActor in
            var recognized = ""
            if let data {
                recognized = await ocr.recognizeText(in: data)
            }
            let cleaned = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { answer = cleaned }
            recognizing = false
        }
    }
    #endif
}

#if canImport(UIKit)

// MARK: - PencilKit canvas bridge (iOS)

/// A thin `UIViewRepresentable` wrapping `PKCanvasView`. The canvas instance is owned
/// by the SwiftUI view (so its `drawing` can be read for recognition); this just wires
/// the tool and lock state.
private struct DrillCanvasRepresentable: UIViewRepresentable {
    let canvas: PKCanvasView
    let isLocked: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: UIColor.label, width: 5)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isUserInteractionEnabled = !isLocked
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = !isLocked
    }
}
#endif
