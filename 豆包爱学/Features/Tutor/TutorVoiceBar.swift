//
//  TutorVoiceBar.swift
//  豆包爱学 — Features/Tutor
//
//  The persistent voice / transcript bar (RESEARCH F18/F19). Shows the live
//  status, a waveform while the teacher narrates, pace control, and a tap target
//  that expands the 字幕 (full narration transcript). Tapping the speaker chip
//  re-reads the current step; the chevron expands/collapses the subtitle sheet.
//

import SwiftUI

struct TutorVoiceBar: View {
    let statusLabel: String
    let isSpeaking: Bool
    let ttsEnabled: Bool
    @Binding var transcriptExpanded: Bool
    let onReplayNarration: () -> Void
    let onToggleTTS: () -> Void

    var body: some View {
        HStack(spacing: DBSpacing.md) {
            // Speaker / mute toggle.
            Button(action: onToggleTTS) {
                Image(systemName: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.dbHeadline)
                    .foregroundStyle(ttsEnabled ? Color.dbPrimary : Color.dbTextTertiary)
                    .frame(width: 40, height: 40)
                    .background(Color.dbPrimarySoft, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ttsEnabled ? "关闭朗读" : "开启朗读")

            // Status + waveform.
            VStack(alignment: .leading, spacing: 2) {
                Text(statusLabel)
                    .font(.dbFootnote.weight(.semibold))
                    .foregroundStyle(Color.dbTextPrimary)
                    .lineLimit(1)
                if isSpeaking {
                    VoiceWaveform(active: true)
                        .frame(height: 12)
                        .foregroundStyle(Color.dbPrimary)
                } else {
                    Text(transcriptExpanded ? "点击收起字幕" : "点击展开字幕")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.3)) { transcriptExpanded.toggle() }
            }

            // Re-read current step.
            Button(action: onReplayNarration) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重读这一步")

            // Expand chevron.
            Button {
                withAnimation(.spring(duration: 0.3)) { transcriptExpanded.toggle() }
            } label: {
                Image(systemName: transcriptExpanded ? "chevron.down" : "chevron.up")
                    .font(.dbCallout.weight(.semibold))
                    .foregroundStyle(Color.dbTextSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(transcriptExpanded ? "收起字幕" : "展开字幕")
        }
        .padding(.horizontal, DBSpacing.md)
        .padding(.vertical, DBSpacing.sm)
        .dbGlassSurface(cornerRadius: DBRadius.pill)
    }
}

// MARK: - Pace control (语速调整, RESEARCH F22)

struct TutorPaceControl: View {
    @Binding var pace: Double

    private let steps: [Double] = [0.75, 1.0, 1.25, 1.5]

    var body: some View {
        HStack(spacing: DBSpacing.xs) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextSecondary)
            ForEach(steps, id: \.self) { value in
                Button {
                    withAnimation(.spring(duration: 0.25)) { pace = value }
                } label: {
                    Text(paceLabel(value))
                        .font(.dbCaption2.weight(.semibold))
                        .foregroundStyle(pace == value ? Color.dbOnPrimary : Color.dbTextSecondary)
                        .padding(.horizontal, DBSpacing.sm)
                        .padding(.vertical, 4)
                        .background(pace == value ? AnyShapeStyle(Color.dbPrimary)
                                                  : AnyShapeStyle(Color.clear),
                                    in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DBSpacing.sm)
        .padding(.vertical, 4)
        .background(Color.dbSurface, in: Capsule(style: .continuous))
        .overlay(Capsule().stroke(Color.dbSeparator, lineWidth: 1))
        .accessibilityLabel("语速 \(paceLabel(pace))")
    }

    private func paceLabel(_ v: Double) -> String {
        switch v {
        case 0.75: "0.75x"
        case 1.0: "1x"
        case 1.25: "1.25x"
        case 1.5: "1.5x"
        default: String(format: "%.2fx", v)
        }
    }
}

// MARK: - Waveform

struct VoiceWaveform: View {
    var active: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !active)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let bars = 14
                let gap: CGFloat = 3
                let barWidth = max(2, (size.width - gap * CGFloat(bars - 1)) / CGFloat(bars))
                for i in 0..<bars {
                    let seed = Double(i) * 0.7
                    let amp = active ? (0.25 + 0.75 * abs(sin(t * 6 + seed))) : 0.2
                    let h = max(2, CGFloat(amp) * size.height)
                    let x = CGFloat(i) * (barWidth + gap)
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: barWidth, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2),
                             with: .style(Color.primary))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Voice bar") {
    struct Wrap: View {
        @State private var expanded = false
        @State private var pace = 1.0
        var body: some View {
            VStack(spacing: 16) {
                TutorVoiceBar(
                    statusLabel: "豆包老师讲解中",
                    isSpeaking: true,
                    ttsEnabled: true,
                    transcriptExpanded: $expanded,
                    onReplayNarration: {},
                    onToggleTTS: {}
                )
                TutorPaceControl(pace: $pace)
            }
            .padding()
            .background(Color.dbBackground)
        }
    }
    return Wrap()
}
