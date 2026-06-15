//
//  LessonPlayerComponents.swift
//  豆包爱学 — Features/Courses/Classroom
//
//  Presentational building blocks for the 豆包课堂 lesson player (CourseDetailView):
//  the course header, chapter (章节) markers, transcript (字幕), the inline 互动习题
//  card, and the playback control rail. All are stateless and design-system-driven
//  so the player view stays declarative; they work identically on iOS and macOS.
//

import SwiftUI

// MARK: - Course header

/// Compact lesson summary shown above the chapter list (regular-width side panel).
struct LessonHeaderCard: View {
    let course: CourseEntity

    private var byline: String {
        let author = course.author.isEmpty ? "豆包老师" : course.author
        let minutes = max(1, course.durationSec / 60)
        return "\(author) · 约 \(minutes) 分钟"
    }

    var body: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.sm) {
                    Image(systemName: course.thumbnailSymbol)
                        .font(.dbTitle2)
                        .foregroundStyle(DBSubjectColor.color(for: course.subject))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.title)
                            .font(.dbHeadline)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(2)
                        Text(byline)
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                }
                HStack(spacing: DBSpacing.sm) {
                    DBSubjectChip(course.subject)
                    DBTag(course.grade.displayName, tint: .dbInfo)
                    if course.isUGC {
                        DBTag("我的课程", tint: .dbAccent)
                    } else if course.reviewVerified {
                        DBTag("三重审核", tint: .dbSecondary)
                    }
                }
                if !course.summary.isEmpty {
                    Text(course.summary)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Chapter markers

/// Horizontal scrollable chapter (章节) rail; tapping jumps the player there.
struct LessonChapterRail: View {
    let segments: [TutorSegment]
    let currentIndex: Int
    let onJump: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.sm) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        Button { onJump(index) } label: {
                            chapterChip(index: index, segment: segment)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.vertical, DBSpacing.xxs)
            }
            .onChange(of: currentIndex) { _, new in
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func chapterChip(index: Int, segment: TutorSegment) -> some View {
        let selected = index == currentIndex
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: DBSpacing.xs) {
                Text("\(index + 1)")
                    .font(.dbCaption2.weight(.bold))
                    .foregroundStyle(selected ? Color.dbOnPrimary : Color.dbTextSecondary)
                    .frame(width: 18, height: 18)
                    .background(selected ? Color.dbPrimary : Color.dbSeparator,
                                in: Circle())
                if segment.checkpoint != nil {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.dbCaption2)
                        .foregroundStyle(selected ? Color.dbPrimary : Color.dbTextTertiary)
                }
            }
            Text(chapterTitle(segment))
                .font(.dbCaption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.dbTextPrimary : Color.dbTextSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 120, alignment: .leading)
        }
        .padding(DBSpacing.sm)
        .frame(width: 150, alignment: .leading)
        .dbSurfaceStyle(cornerRadius: DBRadius.md,
                        fill: selected ? Color.dbPrimarySoft : Color.dbSurface,
                        elevation: selected ? .low : .none)
        .overlay(
            RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                .strokeBorder(selected ? Color.dbPrimary : Color.clear, lineWidth: 1.5)
        )
    }

    private func chapterTitle(_ segment: TutorSegment) -> String {
        if let title = segment.board.first(where: { $0.kind == .title })?.content, !title.isEmpty {
            return title
        }
        if let bullet = segment.board.first(where: { $0.kind == .bullet })?.content, !bullet.isEmpty {
            return bullet
        }
        let narration = segment.narration.trimmingCharacters(in: .whitespacesAndNewlines)
        return narration.isEmpty ? "讲解" : String(narration.prefix(18))
    }
}

// MARK: - Transcript (字幕)

/// Vertical transcript of every segment's narration; the current line is highlighted.
struct LessonTranscriptView: View {
    let segments: [TutorSegment]
    let currentIndex: Int
    let onJump: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                Button { onJump(index) } label: {
                    row(index: index, segment: segment)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dbSurfaceStyle(cornerRadius: DBRadius.lg, fill: Color.dbSurface, elevation: .none)
    }

    private func row(index: Int, segment: TutorSegment) -> some View {
        let active = index == currentIndex
        return HStack(alignment: .top, spacing: DBSpacing.sm) {
            Text("\(index + 1)")
                .font(.dbCaption2.weight(.bold))
                .foregroundStyle(active ? Color.dbOnPrimary : Color.dbTextTertiary)
                .frame(width: 20, height: 20)
                .background(active ? Color.dbPrimary : Color.dbBackgroundAlt, in: Circle())
            Text(segment.narration)
                .font(active ? .dbCallout.weight(.semibold) : .dbFootnote)
                .foregroundStyle(active ? Color.dbTextPrimary : Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, DBSpacing.xxs)
    }
}

// MARK: - Inline 互动习题

/// Inline interactive question shown at a TutorCheckpoint. Once answered it reveals
/// correctness + explanation; the player can then continue to the next chapter.
struct LessonCheckpointCard: View {
    let checkpoint: TutorCheckpoint
    /// nil while unanswered; the chosen option index once answered.
    let selection: Int?
    let onAnswer: (Int) -> Void

    private var isAnswered: Bool { selection != nil }
    private var isCorrect: Bool { selection == checkpoint.answerIndex }

    var body: some View {
        DBCard(fill: cardFill, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                Label("互动习题", systemImage: "checklist")
                    .font(.dbCaption.weight(.semibold))
                    .foregroundStyle(Color.dbPrimary)

                Text(checkpoint.prompt)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: DBSpacing.sm) {
                    ForEach(Array(checkpoint.options.enumerated()), id: \.offset) { index, option in
                        optionButton(index: index, option: option)
                    }
                }

                if isAnswered {
                    feedback
                }
            }
        }
    }

    private var cardFill: Color {
        guard isAnswered else { return Color.dbSurfaceRaised }
        return isCorrect ? Color.dbSuccessSoft : Color.dbErrorSoft
    }

    private func optionButton(index: Int, option: String) -> some View {
        let chosen = selection == index
        let isAnswer = index == checkpoint.answerIndex
        let tint: Color = {
            guard isAnswered else { return chosen ? Color.dbPrimary : Color.dbSeparator }
            if isAnswer { return Color.dbSuccess }
            if chosen { return Color.dbError }
            return Color.dbSeparator
        }()
        return Button {
            guard !isAnswered else { return }
            onAnswer(index)
        } label: {
            HStack(spacing: DBSpacing.sm) {
                Image(systemName: optionSymbol(chosen: chosen, isAnswer: isAnswer))
                    .font(.dbBody)
                    .foregroundStyle(tint)
                Text(option)
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbTextPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                    .strokeBorder(tint, lineWidth: chosen || (isAnswered && isAnswer) ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
    }

    private func optionSymbol(chosen: Bool, isAnswer: Bool) -> String {
        guard isAnswered else { return chosen ? "largecircle.fill.circle" : "circle" }
        if isAnswer { return "checkmark.circle.fill" }
        if chosen { return "xmark.circle.fill" }
        return "circle"
    }

    private var feedback: some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: isCorrect ? "hand.thumbsup.fill" : "lightbulb.fill")
                .foregroundStyle(isCorrect ? Color.dbSuccess : Color.dbWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(isCorrect ? "答对啦！" : "再想想看～")
                    .font(.dbFootnote.weight(.semibold))
                    .foregroundStyle(Color.dbTextPrimary)
                if !checkpoint.explanation.isEmpty {
                    Text(checkpoint.explanation)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Playback control rail

/// Progress + transport (back / replay / continue) + TTS / pace controls.
struct LessonControlRail: View {
    let progress: Double
    let stepText: String
    let canGoBack: Bool
    let canAdvance: Bool
    let isSpeaking: Bool
    let ttsEnabled: Bool
    @Binding var transcriptOpen: Bool
    @Binding var pace: Double

    let onBack: () -> Void
    let onReplay: () -> Void
    let onAdvance: () -> Void
    let onRepeatNarration: () -> Void
    let onToggleTTS: () -> Void

    var body: some View {
        VStack(spacing: DBSpacing.sm) {
            HStack(spacing: DBSpacing.sm) {
                Text(stepText)
                    .font(.dbCaption.weight(.semibold))
                    .foregroundStyle(Color.dbTextSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextTertiary)
            }
            ProgressView(value: progress)
                .tint(Color.dbPrimary)

            HStack(spacing: DBSpacing.md) {
                transportButton(systemImage: "chevron.left", label: "上一节",
                                action: onBack, enabled: canGoBack)
                transportButton(systemImage: "arrow.counterclockwise", label: "再讲一遍",
                                action: onReplay, enabled: true)
                Spacer()
                Button(action: onAdvance) {
                    Label(canAdvance ? "继续学习" : "已是最后一节", systemImage: "chevron.right")
                        .font(.dbBodyEmph)
                }
                .buttonStyle(.db(.primary))
                .disabled(!canAdvance)
            }

            HStack(spacing: DBSpacing.md) {
                Button(action: onToggleTTS) {
                    Label(ttsEnabled ? "语音开" : "语音关",
                          systemImage: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.dbFootnote.weight(.semibold))
                }
                .buttonStyle(.db(.ghost))

                Button(action: onRepeatNarration) {
                    Label("重听", systemImage: "memories")
                        .font(.dbFootnote.weight(.semibold))
                }
                .buttonStyle(.db(.ghost))
                .disabled(!ttsEnabled)

                Spacer()

                Button { withAnimation(.spring(duration: 0.3)) { transcriptOpen.toggle() } } label: {
                    Label("字幕", systemImage: transcriptOpen ? "text.bubble.fill" : "text.bubble")
                        .font(.dbFootnote.weight(.semibold))
                }
                .buttonStyle(.db(.ghost))
            }

            paceControl
        }
    }

    private func transportButton(systemImage: String, label: String,
                                 action: @escaping () -> Void, enabled: Bool) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage).font(.dbBody)
                Text(label).font(.dbCaption2)
            }
            .foregroundStyle(enabled ? Color.dbPrimary : Color.dbTextTertiary)
            .frame(minWidth: 48)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var paceLabel: String {
        let trimmed = pace.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(pace))
            : String(format: "%.2f", pace)
        return "\(trimmed)x"
    }

    private var paceControl: some View {
        HStack(spacing: DBSpacing.sm) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
            Text("语速")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextSecondary)
            Slider(value: $pace, in: 0.75...1.5, step: 0.25)
                .tint(Color.dbPrimary)
            Text(paceLabel)
                .font(.dbCaption.monospacedDigit())
                .foregroundStyle(Color.dbTextSecondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Previews

#Preview("互动习题") {
    VStack(spacing: DBSpacing.lg) {
        LessonCheckpointCard(
            checkpoint: TutorCheckpoint(
                prompt: "假设全是鸡，35 只一共有多少只脚？",
                options: ["35 只", "70 只", "94 只"],
                answerIndex: 1,
                explanation: "每只鸡 2 只脚，35 × 2 = 70 只脚。"),
            selection: 1,
            onAnswer: { _ in })
        LessonCheckpointCard(
            checkpoint: TutorCheckpoint(
                prompt: "多出来的脚是谁的？",
                options: ["鸡的", "兔的"],
                answerIndex: 1,
                explanation: "兔比鸡多 2 只脚，多出来的脚都来自兔子。"),
            selection: nil,
            onAnswer: { _ in })
    }
    .padding()
    .background(Color.dbBackground)
}
