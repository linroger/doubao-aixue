//
//  TutorFollowUpPanel.swift
//  豆包爱学 — Features/Tutor
//
//  追问 / 即时打断提问 (RESEARCH F20). A compact conversation thread anchored to
//  the session: the student can interrupt at any time, type or speak a follow-up,
//  and the tutor answers contextually (streamed via the chat endpoint) before
//  resuming the explanation. Includes a quick-question chip rail and a composer
//  with a typed field + hold-to-talk mic.
//

import SwiftUI

struct TutorFollowUpPanel: View {
    let followUps: [TutorFollowUp]
    let isAnswering: Bool
    let suggestions: [String]
    @Binding var draft: String
    let isListeningVoice: Bool
    let onSend: () -> Void
    let onPickSuggestion: (String) -> Void
    let onPressMic: () -> Void
    let onReleaseMic: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("随时追问", subtitle: "听不明白？打断我问问～", systemImage: "hand.raised.fill")

            // Thread.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DBSpacing.sm) {
                        if followUps.isEmpty {
                            emptyState
                        } else {
                            ForEach(followUps) { turn in
                                FollowUpBubble(turn: turn)
                                    .id(turn.id)
                            }
                        }
                        if isAnswering {
                            HStack(spacing: DBSpacing.xs) {
                                ProgressView().controlSize(.small)
                                Text("豆包老师正在回答…")
                                    .font(.dbCaption)
                                    .foregroundStyle(Color.dbTextSecondary)
                            }
                            .id("answering")
                        }
                        Color.clear.frame(height: 1).id("thread-bottom")
                    }
                    .padding(.vertical, DBSpacing.xs)
                }
                .onChange(of: followUps.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("thread-bottom", anchor: .bottom) }
                }
                .onChange(of: lastTurnText) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("thread-bottom", anchor: .bottom) }
                }
            }

            // Suggestion chips.
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DBSpacing.sm) {
                        ForEach(suggestions, id: \.self) { s in
                            Button { onPickSuggestion(s) } label: {
                                DBChip(s, systemImage: "questionmark.circle", tint: .dbSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            composer
        }
    }

    private var lastTurnText: String { followUps.last?.text ?? "" }

    private var emptyState: some View {
        HStack(spacing: DBSpacing.sm) {
            DBMascot(mood: .happy, size: 36)
            Text("有不懂的地方，随时打断我提问，比如“为什么要这样设？”")
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DBSpacing.sm)
    }

    private var composer: some View {
        HStack(spacing: DBSpacing.sm) {
            TextField("输入你的问题…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.dbBody)
                .lineLimit(1...3)
                .padding(.horizontal, DBSpacing.md)
                .padding(.vertical, DBSpacing.sm)
                .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                    .stroke(Color.dbSeparator, lineWidth: 1))
                .onSubmit(onSend)

            // Hold-to-talk mic for spoken follow-ups.
            Image(systemName: isListeningVoice ? "waveform" : "mic.fill")
                .font(.dbHeadline)
                .foregroundStyle(isListeningVoice ? Color.dbOnPrimary : Color.dbPrimary)
                .frame(width: 42, height: 42)
                .background(isListeningVoice ? AnyShapeStyle(Color.dbPrimary)
                                             : AnyShapeStyle(Color.dbPrimarySoft), in: Circle())
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !isListeningVoice { onPressMic() } }
                        .onEnded { _ in onReleaseMic() }
                )
                .accessibilityLabel("按住语音提问")

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? Color.dbTextTertiary : Color.dbPrimary)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("发送问题")
        }
    }
}

// MARK: - Bubble

private struct FollowUpBubble: View {
    let turn: TutorFollowUp
    private var isUser: Bool { turn.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            if isUser { Spacer(minLength: 32) }
            if !isUser {
                Image(systemName: "graduationcap.fill")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbPrimary)
                    .frame(width: 26, height: 26)
                    .background(Color.dbPrimarySoft, in: Circle())
            }
            Text(turn.text.isEmpty ? "…" : turn.text)
                .font(.dbCallout)
                .foregroundStyle(isUser ? Color.dbOnPrimary : Color.dbTextPrimary)
                .padding(.horizontal, DBSpacing.md)
                .padding(.vertical, DBSpacing.sm)
                .background(
                    isUser ? AnyShapeStyle(Color.dbPrimary) : AnyShapeStyle(Color.dbBackgroundAlt),
                    in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                )
                .frame(maxWidth: 260, alignment: isUser ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if !isUser { Spacer(minLength: 32) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

#Preview("Follow-up") {
    struct Wrap: View {
        @State private var draft = ""
        var body: some View {
            TutorFollowUpPanel(
                followUps: [
                    TutorFollowUp(role: .user, text: "为什么要假设全是鸡？", atSegmentIndex: 1),
                    TutorFollowUp(role: .assistant, text: "好问题！先假设全是鸡，是因为这样脚的数量最少，多出来的脚一定来自兔子，就能算出兔子有几只啦。", atSegmentIndex: 1)
                ],
                isAnswering: false,
                suggestions: ["能再举个例子吗？", "这一步有什么用？", "换个简单的方法"],
                draft: $draft,
                isListeningVoice: false,
                onSend: {}, onPickSuggestion: { _ in }, onPressMic: {}, onReleaseMic: {}
            )
            .padding()
            .background(Color.dbBackground)
        }
    }
    return Wrap()
}
