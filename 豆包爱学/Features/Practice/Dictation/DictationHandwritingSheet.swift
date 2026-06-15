//
//  DictationHandwritingSheet.swift
//  豆包爱学 — Features/Practice/Dictation
//
//  iOS-only 手写 input for 听写. A PencilKit canvas lets the child write the word
//  with finger / Apple Pencil; "识别" rasterises the strokes to image data and hands
//  it back so the session model can run on-device OCR into the answer field.
//  macOS keeps typed input only, so this whole feature is iOS-guarded.
//

#if os(iOS)
import SwiftUI
import PencilKit

struct DictationHandwritingSheet: View {
    let entry: DictationEntry
    /// Called with rasterised stroke image data when the child taps 识别.
    let onRecognize: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()

    var body: some View {
        NavigationStack {
            VStack(spacing: DBSpacing.lg) {
                if !entry.reading.isEmpty || !entry.meaning.isEmpty {
                    DBCard {
                        VStack(alignment: .leading, spacing: DBSpacing.xs) {
                            if !entry.reading.isEmpty {
                                Text(entry.reading)
                                    .font(.dbCallout)
                                    .foregroundStyle(Color.dbTextSecondary)
                            }
                            if !entry.meaning.isEmpty {
                                Text(entry.meaning)
                                    .font(.dbFootnote)
                                    .foregroundStyle(Color.dbTextTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, DBSpacing.screenInset)
                }

                DictationCanvas(canvasView: $canvasView)
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .background(Color.dbSurface)
                    .clipShape(RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                            .strokeBorder(Color.dbSeparator, lineWidth: 1)
                    )
                    .padding(.horizontal, DBSpacing.screenInset)

                Text("用手指或 Apple Pencil 把字写在框里，点「识别」自动填入。")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DBSpacing.screenInset)

                Spacer(minLength: 0)

                HStack(spacing: DBSpacing.md) {
                    Button {
                        canvasView.drawing = PKDrawing()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .buttonStyle(.db(.secondary))

                    Button {
                        recognize()
                    } label: {
                        Label("识别", systemImage: "sparkles")
                    }
                    .buttonStyle(.db(.primary, fullWidth: true))
                }
                .padding(.horizontal, DBSpacing.screenInset)
                .padding(.bottom, DBSpacing.lg)
            }
            .background(Color.dbBackground)
            .navigationTitle("手写默写")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func recognize() {
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else { dismiss(); return }
        let bounds = drawing.bounds.insetBy(dx: -16, dy: -16)
        // Render at the canvas's own display scale (iOS 26 deprecates UIScreen.main).
        let displayScale = canvasView.traitCollection.displayScale
        let image = drawing.image(from: bounds, scale: displayScale > 0 ? displayScale : 2)
        // Composite on white so OCR sees dark-on-light strokes.
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let composited = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
        if let data = composited.pngData() {
            onRecognize(data)
        }
        dismiss()
    }
}

// MARK: - PencilKit canvas bridge

private struct DictationCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 6)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

#Preview {
    DictationHandwritingSheet(
        entry: DictationEntry(text: "理想", reading: "lǐ xiǎng", meaning: "对未来的美好设想"),
        onRecognize: { _ in }
    )
}
#endif
