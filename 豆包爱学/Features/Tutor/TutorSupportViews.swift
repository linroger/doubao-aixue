//
//  TutorSupportViews.swift
//  豆包爱学 — Features/Tutor
//
//  Secondary surfaces for 豆包老师: the 字幕 (subtitle / full-narration transcript)
//  that expands from behind the voice bar, the problem pane (shown in the regular
//  3-pane layout), and the progress/step rail.
//

import SwiftUI

// MARK: - Transcript (字幕)

/// The full spoken-narration transcript, the "secondary, tappable layer behind
/// voice chips" (RESEARCH §5). Highlights the segment currently on the board.
struct TutorTranscriptView: View {
    let segments: [TutorSegment]
    let currentIndex: Int
    let onJump: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            HStack(spacing: DBSpacing.xs) {
                Image(systemName: "captions.bubble.fill")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbSecondary)
                Text("字幕")
                    .font(.dbSubheadline.weight(.semibold))
                    .foregroundStyle(Color.dbTextPrimary)
                Spacer()
            }
            if segments.isEmpty {
                Text("讲解开始后这里会显示完整字幕")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
            } else {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    Button { onJump(index) } label: {
                        HStack(alignment: .top, spacing: DBSpacing.sm) {
                            Image(systemName: index == currentIndex ? "speaker.wave.2.fill" : "circle.fill")
                                .font(index == currentIndex ? .dbFootnote : .system(size: 5))
                                .foregroundStyle(index == currentIndex ? Color.dbPrimary : Color.dbTextTertiary)
                                .frame(width: 18)
                                .padding(.top, index == currentIndex ? 1 : 6)
                            Text(segment.narration)
                                .font(.dbFootnote)
                                .foregroundStyle(index == currentIndex ? Color.dbTextPrimary : Color.dbTextSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, DBSpacing.sm)
                        .background(index == currentIndex ? AnyShapeStyle(Color.dbPrimarySoft.opacity(0.5))
                                                          : AnyShapeStyle(Color.clear),
                                    in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        .dbShadow(.low)
    }
}

// MARK: - Problem pane

/// The original problem, shown in the regular-width left pane (RESEARCH F18 UI).
struct TutorProblemPane: View {
    let problemText: String
    let subject: Subject
    let grade: GradeLevel
    let route: IntelligenceRoute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("本题", systemImage: "doc.text.fill") {
                    DBRouteBadge(route)
                }
                HStack(spacing: DBSpacing.xs) {
                    DBSubjectChip(subject, isSelected: true)
                    DBChip(grade.displayName, systemImage: "graduationcap", tint: .dbSecondary)
                }
                DBCard(fill: .dbSurfaceRaised) {
                    MathText(problemText, font: .dbBody)
                        .foregroundStyle(Color.dbTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DBCard(fill: .dbSecondarySoft, elevation: .none) {
                    HStack(alignment: .top, spacing: DBSpacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Color.dbSecondary)
                        Text("豆包老师会一步一步带你解，不直接给答案。听不懂随时打断追问哦～")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(DBSpacing.lg)
        }
        .background(Color.dbBackground)
    }
}

// MARK: - Step progress rail

/// A slim segment-progress indicator with prev / replay / next controls.
struct TutorProgressRail: View {
    let progress: Double
    let stepText: String
    let canGoBack: Bool
    let canAdvance: Bool
    let onBack: () -> Void
    let onReplay: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        HStack(spacing: DBSpacing.md) {
            Button(action: onBack) {
                Image(systemName: "backward.fill")
                    .font(.dbCallout)
                    .foregroundStyle(canGoBack ? Color.dbPrimary : Color.dbTextTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)
            .accessibilityLabel("上一步")

            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .tint(Color.dbPrimary)
                Text(stepText)
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextSecondary)
            }

            Button(action: onReplay) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("再讲一遍")

            Button(action: onAdvance) {
                Image(systemName: "forward.fill")
                    .font(.dbCallout)
                    .foregroundStyle(canAdvance ? Color.dbPrimary : Color.dbTextTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .accessibilityLabel("下一步")
        }
        .padding(.horizontal, DBSpacing.md)
        .padding(.vertical, DBSpacing.xs)
    }
}

#Preview("Transcript") {
    TutorTranscriptView(
        segments: [
            TutorSegment(narration: "我们一起来看这道题。别急着要答案，先想想它在考什么。"),
            TutorSegment(narration: "第1步，假设全是鸡。这样脚的数量最少。"),
            TutorSegment(narration: "第2步，多出来的脚都是兔子的，除以2就是兔子的只数。")
        ],
        currentIndex: 1,
        onJump: { _ in }
    )
    .padding()
    .background(Color.dbBackground)
}

#Preview("Problem pane") {
    TutorProblemPane(
        problemText: "笼子里有若干只鸡和兔，共 35 个头，94 只脚。问鸡和兔各有多少只？",
        subject: .math, grade: .g3, route: .mock
    )
}
