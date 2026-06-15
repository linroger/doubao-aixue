//
//  TutorCheckpointBar.swift
//  豆包爱学 — Features/Tutor
//
//  The comprehension-check surface (RESEARCH F19 "是否听懂了?"). At a
//  TutorCheckpoint the teacher pauses and asks aloud; the student answers by
//  HOLDING the mic (hold-to-talk, via SpeechRecognitionCoordinator) or by tapping
//  a typed-reply chip. On "听懂了" the session continues; on "再讲一遍" it replays
//  the step. The hold-to-talk gesture shows a live waveform and, on release,
//  resolves the transcript intent (understood / confused).
//

import SwiftUI

struct TutorCheckpointBar: View {
    let checkpoint: TutorCheckpoint
    let isListening: Bool
    /// Called when the student presses the mic (start ASR).
    let onPressMic: () -> Void
    /// Called when the student releases the mic; pass the simulated word to ASR.
    let onReleaseMic: () -> Void
    /// Typed-reply fallback: continue / replay.
    let onTypedReply: (_ understood: Bool) -> Void

    var body: some View {
        VStack(spacing: DBSpacing.md) {
            // Prompt.
            HStack(spacing: DBSpacing.sm) {
                DBMascot(mood: .curious, size: 34)
                Text(checkpoint.prompt)
                    .font(.dbHeadline)
                    .foregroundStyle(Color.dbTextPrimary)
                Spacer(minLength: 0)
            }

            // Hold-to-talk mic — the primary spoken-dialogue affordance.
            HoldToTalkButton(isListening: isListening,
                             onPress: onPressMic,
                             onRelease: onReleaseMic)

            // Typed-reply fallback chips, driven by the checkpoint's options.
            HStack(spacing: DBSpacing.sm) {
                ForEach(Array(checkpoint.options.enumerated()), id: \.offset) { index, option in
                    let understood = index == 0
                    Button {
                        onTypedReply(understood)
                    } label: {
                        Label(option, systemImage: understood ? "checkmark.circle.fill" : "arrow.counterclockwise")
                            .font(.dbFootnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.db(understood ? .secondary : .ghost, fullWidth: true))
                }
            }
        }
        .padding(DBSpacing.lg)
        .background(Color.dbSurfaceRaised, in: RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous)
                .strokeBorder(Color.dbPrimarySoft, lineWidth: 1.5)
        )
        .dbShadow(.medium)
    }
}

// MARK: - Hold-to-talk button

struct HoldToTalkButton: View {
    let isListening: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: DBSpacing.xs) {
            ZStack {
                Circle()
                    .fill(isListening ? Color.dbPrimary : Color.dbPrimarySoft)
                    .frame(width: 76, height: 76)
                    .overlay {
                        if isListening {
                            Circle().stroke(Color.dbPrimary.opacity(0.35), lineWidth: 8)
                                .scaleEffect(isPressed ? 1.35 : 1.0)
                                .opacity(isPressed ? 0 : 1)
                                .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isPressed)
                        }
                    }
                if isListening {
                    VoiceWaveform(active: true)
                        .frame(width: 40, height: 24)
                        .foregroundStyle(Color.dbOnPrimary)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.dbPrimary)
                }
            }
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(.spring(duration: 0.25), value: isPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
                    }
            )
            .accessibilityLabel("按住说话回答")
            .accessibilityHint("按住麦克风回答老师，松开提交")

            Text(isListening ? "正在听…松开结束" : "按住说话")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextSecondary)
        }
    }
}

#Preview("Checkpoint") {
    TutorCheckpointBar(
        checkpoint: TutorCheckpoint(
            prompt: "到这里听懂了吗？",
            options: ["听懂了", "再讲一遍"],
            answerIndex: 0,
            explanation: "很好，那我们继续。"
        ),
        isListening: false,
        onPressMic: {},
        onReleaseMic: {},
        onTypedReply: { _ in }
    )
    .padding()
    .background(Color.dbBackground)
}
