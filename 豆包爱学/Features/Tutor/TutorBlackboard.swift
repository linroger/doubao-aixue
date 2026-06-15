//
//  TutorBlackboard.swift
//  豆包爱学 — Features/Tutor
//
//  The 动态板书 (dynamic blackboard) — the PRIMARY surface of 豆包老师. A dark,
//  rounded "chalkboard" onto which BoardElements (title / bullet / formula /
//  highlight / answer / divider) appear progressively as each TutorSegment
//  streams in, synced with the TTS narration. Formulas render via MathText.
//
//  Deliberately avatar-free (RESEARCH §5: "voice + board + key-points"); the
//  warmth comes from soft chalk colours, a faint dust texture, and a gentle
//  "writing" entrance animation per element.
//

import SwiftUI

struct TutorBlackboard: View {
    /// Elements currently revealed (the model exposes a progressive prefix).
    let elements: [BoardElement]
    /// Title shown on the board frame (the problem step / lesson label).
    let stepCaption: String
    /// Whether the teacher is actively narrating (drives the chalk shimmer).
    let isSpeaking: Bool

    // Chalk palette — warm whites & accents that read on a dark board in both
    // light and dark mode (the board itself is intentionally always dark).
    private let chalkPrimary = Color(white: 0.97)
    private let chalkSoft = Color(white: 0.78)
    private let chalkAccent = Color(red: 1.0, green: 0.86, blue: 0.55)   // warm yellow chalk
    private let chalkAnswer = Color(red: 0.62, green: 0.92, blue: 0.74)  // green "answer" chalk

    var body: some View {
        ZStack(alignment: .topLeading) {
            boardBackground

            VStack(alignment: .leading, spacing: 0) {
                boardHeader
                Divider().overlay(Color.white.opacity(0.12))
                    .padding(.top, DBSpacing.sm)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: DBSpacing.md) {
                            if elements.isEmpty {
                                emptyBoard
                            } else {
                                ForEach(Array(elements.enumerated()), id: \.element.id) { index, element in
                                    boardRow(element)
                                        .id(element.id)
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.92, anchor: .leading)
                                                .combined(with: .opacity)
                                                .combined(with: .move(edge: .leading)),
                                            removal: .opacity))
                                }
                            }
                            Color.clear.frame(height: 4).id("board-bottom")
                        }
                        .padding(.top, DBSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: elements.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.35)) {
                            proxy.scrollTo("board-bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .padding(DBSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .dbShadow(.medium)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("动态板书")
    }

    // MARK: Board chrome

    private var boardBackground: some View {
        ZStack {
            // Deep slate gradient — a classroom chalkboard.
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.16, blue: 0.16),
                         Color(red: 0.07, green: 0.11, blue: 0.13)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Faint chalk-dust speckle for texture.
            Canvas { context, size in
                var generator = SeededGenerator(seed: 42)
                let width = Double(size.width)
                let height = Double(size.height)
                for _ in 0..<70 {
                    let x = Double.random(in: 0...max(width, 1), using: &generator)
                    let y = Double.random(in: 0...max(height, 1), using: &generator)
                    let r = Double.random(in: 0.4...1.4, using: &generator)
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.05)))
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var boardHeader: some View {
        HStack(spacing: DBSpacing.sm) {
            Image(systemName: "graduationcap.fill")
                .font(.dbCallout)
                .foregroundStyle(chalkAccent)
            Text(stepCaption.isEmpty ? "动态板书" : stepCaption)
                .font(.dbSubheadline.weight(.semibold))
                .foregroundStyle(chalkPrimary)
                .lineLimit(1)
            Spacer(minLength: DBSpacing.sm)
            if isSpeaking {
                ChalkWaveform()
                    .frame(width: 28, height: 16)
                    .foregroundStyle(chalkAccent)
            }
        }
    }

    private var emptyBoard: some View {
        HStack(spacing: DBSpacing.sm) {
            ProgressView().controlSize(.small).tint(chalkSoft)
            Text("豆包老师正在准备讲解…")
                .font(.dbCallout)
                .foregroundStyle(chalkSoft)
        }
        .padding(.vertical, DBSpacing.lg)
    }

    // MARK: Element rows

    @ViewBuilder
    private func boardRow(_ element: BoardElement) -> some View {
        switch element.kind {
        case .title:
            Text(element.content)
                .font(.dbTitle3.weight(.bold))
                .foregroundStyle(chalkPrimary)
                .underlineChalk(chalkAccent)

        case .text:
            Text(element.content)
                .font(.dbBody)
                .foregroundStyle(chalkSoft)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: DBSpacing.sm) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(chalkAccent)
                    .padding(.top, 6)
                Text(element.content)
                    .font(.dbBodyEmph)
                    .foregroundStyle(chalkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .formula:
            MathText(element.content, font: .dbTitle3)
                .foregroundStyle(chalkPrimary)
                .padding(.horizontal, DBSpacing.md)
                .padding(.vertical, DBSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))

        case .highlight:
            HStack(alignment: .firstTextBaseline, spacing: DBSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.dbFootnote)
                    .foregroundStyle(chalkAccent)
                Text(element.content)
                    .font(.dbBodyEmph)
                    .foregroundStyle(chalkAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DBSpacing.md)
            .padding(.vertical, DBSpacing.sm)
            .background(chalkAccent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))

        case .divider:
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
                .padding(.vertical, DBSpacing.xxs)

        case .answer:
            HStack(alignment: .firstTextBaseline, spacing: DBSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(chalkAnswer)
                MathText(element.content, font: .dbTitle3)
                    .foregroundStyle(chalkAnswer)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chalkAnswer.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                    .strokeBorder(chalkAnswer.opacity(0.5), lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Chalk underline modifier

private extension View {
    func underlineChalk(_ color: Color) -> some View {
        self.overlay(alignment: .bottomLeading) {
            color.opacity(0.6)
                .frame(height: 2)
                .offset(y: 4)
        }
    }
}

// MARK: - Chalk waveform (speaking indicator)

private struct ChalkWaveform: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: false)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let bars = 4
                let barWidth = size.width / CGFloat(bars * 2 - 1)
                for i in 0..<bars {
                    let seed = Double(i) * 1.3
                    let amp = 0.4 + 0.6 * abs(sin(t * 5 + seed))
                    let h = CGFloat(amp) * size.height
                    let x = CGFloat(i) * barWidth * 2
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: barWidth, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2),
                             with: .style(Color.primary))
                }
            }
        }
    }
}

// MARK: - Deterministic RNG for the chalk-dust texture
// Uses the shared `SeededGenerator` (SplitMix64) defined in VocabularySupport.swift.

#Preview("Blackboard") {
    TutorBlackboard(
        elements: [
            BoardElement(kind: .title, content: "鸡兔同笼"),
            BoardElement(kind: .bullet, content: "1. 假设全是鸡"),
            BoardElement(kind: .formula, content: "35 \\times 2 = 70"),
            BoardElement(kind: .highlight, content: "多出来的脚都是兔子的"),
            BoardElement(kind: .formula, content: "(94 - 70) \\div 2 = 12"),
            BoardElement(kind: .answer, content: "兔 = 12，鸡 = 23")
        ],
        stepCaption: "第 2 步 · 抬腿法",
        isSpeaking: true
    )
    .frame(height: 460)
    .padding()
    .background(Color.dbBackground)
}
