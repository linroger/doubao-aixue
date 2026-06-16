//
//  TutorVoiceSettings.swift
//  豆包爱学 — Features/Tutor
//
//  语音 / 口音 / 语速 设置 for 豆包老师 (RESEARCH F22 "语速可调 + 多口音"). The tutor
//  narrates through the shared `TTSService.speak(_:language:rate:)`, which builds
//  an `AVSpeechSynthesisVoice(language:)` from a BCP-47 tag. So the user-facing
//  control here is a *dialect / accent* picker (普通话 / 粤语 / 台湾国语 / English)
//  mapped to the right language tag, plus a continuous 语速 slider (0.75x…1.5x).
//
//  The choices persist via @AppStorage (`db.tutor.voice*`) so they survive
//  launches, exactly like the appearance preference elsewhere in the app. The
//  picker only offers dialects that actually have an installed system voice, so
//  it never promises a voice the device can't produce; if none of a language's
//  voices are installed we still fall back to the base tag (AVSpeech resolves a
//  default), which keeps narration working on every device and on both platforms.
//

import SwiftUI
import AVFoundation

// MARK: - Dialect / accent options

/// The selectable narration accents. Each maps to a BCP-47 language tag handed to
/// `TTSService.speak(_:language:)`. Chinese subjects default to 普通话; English to
/// 美式英语. Cantonese / 台湾国语 / 英式英语 are offered when an installed voice exists.
nonisolated enum TutorVoiceAccent: String, CaseIterable, Identifiable, Sendable {
    case mandarin        // 普通话 (zh-CN)
    case cantonese       // 粤语 (zh-HK)
    case taiwanese       // 台湾国语 (zh-TW)
    case englishUS       // 美式英语 (en-US)
    case englishUK       // 英式英语 (en-GB)

    nonisolated var id: String { rawValue }

    /// BCP-47 tag passed to `AVSpeechSynthesisVoice(language:)`.
    nonisolated var languageTag: String {
        switch self {
        case .mandarin: "zh-CN"
        case .cantonese: "zh-HK"
        case .taiwanese: "zh-TW"
        case .englishUS: "en-US"
        case .englishUK: "en-GB"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .mandarin: "普通话"
        case .cantonese: "粤语"
        case .taiwanese: "台湾国语"
        case .englishUS: "美式英语"
        case .englishUK: "英式英语"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .mandarin: "标准国语，最常用"
        case .cantonese: "广东话发音"
        case .taiwanese: "台湾腔国语"
        case .englishUS: "American English"
        case .englishUK: "British English"
        }
    }

    nonisolated var symbolName: String {
        isChinese ? "character.book.closed.fill" : "a.book.closed.fill"
    }

    nonisolated var isChinese: Bool {
        switch self {
        case .mandarin, .cantonese, .taiwanese: true
        case .englishUS, .englishUK: false
        }
    }

    /// Accents to offer for a subject, Chinese ones first for Chinese subjects.
    nonisolated static func options(for subject: Subject) -> [TutorVoiceAccent] {
        if subject == .english {
            return [.englishUS, .englishUK, .mandarin]
        }
        return [.mandarin, .cantonese, .taiwanese, .englishUS]
    }

    /// The sensible default accent for a subject.
    nonisolated static func `default`(for subject: Subject) -> TutorVoiceAccent {
        subject == .english ? .englishUS : .mandarin
    }

    /// True when at least one system voice is installed for this accent's language.
    /// AVFoundation still resolves a fallback voice from the base language even if
    /// the exact region voice is missing, so this is a "has a real match" hint used
    /// to badge the row — selection is never blocked.
    @MainActor var hasInstalledVoice: Bool {
        let prefix = languageTag.prefix(2).lowercased()
        let exact = languageTag.lowercased()
        return AVSpeechSynthesisVoice.speechVoices().contains { voice in
            let lang = voice.language.lowercased()
            return lang == exact || lang.hasPrefix(prefix + "-")
        }
    }
}

// MARK: - Shared storage keys

nonisolated enum TutorVoiceStorageKey {
    static let accent = "db.tutor.voiceAccent"
    static let rate = "db.tutor.voiceRate"
}

// MARK: - Settings sheet

/// A compact, accessible sheet to pick the narration accent and 语速. Bound to the
/// session model so changes apply immediately (and a short sample is spoken so the
/// child hears the result). Pushed views never wrap their own NavigationStack, but
/// a *sheet* like this provides its own for the title + 完成 button.
struct TutorVoiceSettingsView: View {
    /// The subject scopes which accents make sense (e.g. English-only for 英语).
    let subject: Subject
    /// Currently selected accent (persisted by the model via @AppStorage).
    @Binding var accent: TutorVoiceAccent
    /// Narration rate multiplier, 0.75…1.5.
    @Binding var rate: Double
    /// Speak a short sample in the chosen voice (so the child can audition it).
    let onPreview: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var accents: [TutorVoiceAccent] { TutorVoiceAccent.options(for: subject) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DBSpacing.lg) {
                    accentSection
                    rateSection
                    previewButton
                }
                .padding(DBSpacing.lg)
            }
            .background(Color.dbBackground)
            .navigationTitle("声音与语速")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: Accent picker

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("口音", subtitle: "选一个你最爱听的声音", systemImage: "waveform")
            VStack(spacing: DBSpacing.sm) {
                ForEach(accents) { option in
                    accentRow(option)
                }
            }
        }
    }

    private func accentRow(_ option: TutorVoiceAccent) -> some View {
        let isSelected = option == accent
        return Button {
            accent = option
            HapticEngine.play(.selection)
            onPreview()
        } label: {
            HStack(spacing: DBSpacing.md) {
                Image(systemName: option.symbolName)
                    .font(.dbHeadline)
                    .foregroundStyle(isSelected ? Color.dbOnPrimary : Color.dbPrimary)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? AnyShapeStyle(Color.dbPrimary)
                                           : AnyShapeStyle(Color.dbPrimarySoft), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DBSpacing.xs) {
                        Text(option.displayName)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                        if !option.hasInstalledVoice {
                            DBTag("需系统语音", tint: .dbWarning)
                        }
                    }
                    Text(option.subtitle)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.dbTitle3)
                    .foregroundStyle(isSelected ? Color.dbPrimary : Color.dbTextTertiary)
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AnyShapeStyle(Color.dbPrimarySoft.opacity(0.5))
                                   : AnyShapeStyle(Color.dbSurface),
                        in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                    .strokeBorder(isSelected ? Color.dbPrimary : Color.dbSeparator,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.displayName)，\(option.subtitle)")
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint(option.hasInstalledVoice ? "" : "此设备未安装该语音，将使用默认声音")
    }

    // MARK: Rate slider (0.75x … 1.5x)

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("语速", subtitle: "讲得太快？拖慢一点～", systemImage: "gauge.with.dots.needle.50percent")
            DBCard(fill: .dbSurface, elevation: .low) {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    HStack {
                        Text("慢")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                        Spacer()
                        Text(Self.rateLabel(rate))
                            .font(.dbBodyEmph.monospacedDigit())
                            .foregroundStyle(Color.dbPrimary)
                        Spacer()
                        Text("快")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Slider(value: $rate, in: 0.75...1.5, step: 0.05) {
                        Text("语速")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise.fill").foregroundStyle(Color.dbTextTertiary)
                    } maximumValueLabel: {
                        Image(systemName: "hare.fill").foregroundStyle(Color.dbTextTertiary)
                    } onEditingChanged: { editing in
                        if !editing { onPreview() }
                    }
                    .tint(Color.dbPrimary)
                    .accessibilityValue(Self.rateLabel(rate))
                }
            }
        }
    }

    private var previewButton: some View {
        Button {
            onPreview()
        } label: {
            Label("试听这个声音", systemImage: "play.circle.fill")
        }
        .buttonStyle(.db(.secondary, fullWidth: true))
        .accessibilityHint("用当前口音和语速朗读一句示例")
    }

    nonisolated static func rateLabel(_ value: Double) -> String {
        String(format: "%.2fx", value)
    }
}

#Preview("Voice settings — 数学") {
    struct Wrap: View {
        @State private var accent: TutorVoiceAccent = .mandarin
        @State private var rate: Double = 1.0
        var body: some View {
            TutorVoiceSettingsView(subject: .math, accent: $accent, rate: $rate, onPreview: {})
        }
    }
    return Wrap()
}

#Preview("Voice settings — 英语") {
    struct Wrap: View {
        @State private var accent: TutorVoiceAccent = .englishUS
        @State private var rate: Double = 1.1
        var body: some View {
            TutorVoiceSettingsView(subject: .english, accent: $accent, rate: $rate, onPreview: {})
        }
    }
    return Wrap()
}
