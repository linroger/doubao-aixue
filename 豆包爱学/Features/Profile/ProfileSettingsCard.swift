//
//  ProfileSettingsCard.swift
//  豆包爱学 — Features/Profile
//
//  设置 sub-section: appearance, voice (TTSService), 智能来源 (preferredRoute),
//  学习模式 (anti-cheat learnMode on LearnerProfile), and 恢复示例数据.
//  All edits persist to SwiftData; appearance persists via @AppStorage and is
//  applied to the personal center subtree.
//

import SwiftUI

/// Appearance preference shared via @AppStorage so the choice survives launches.
/// Stored as a String raw value; `.system` follows the OS setting.
enum ProfileAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct ProfileSettingsCard: View {
    @Bindable var profile: LearnerProfile
    let onRestoreSampleData: () -> Void

    @Environment(TTSService.self) private var tts
    @Environment(AICredentialStore.self) private var ai
    @AppStorage("db.appearance") private var appearanceRaw: String = ProfileAppearance.system.rawValue
    // Account state (shared with AccountView via the db.account.* keys).
    @AppStorage(AccountStorageKey.type) private var accountTypeRaw: String = AccountType.none.rawValue
    // Daily-reminder preference; drives a real local notification via NotificationService.
    @AppStorage("db.notifications.enabled") private var notificationsEnabled = false
    @State private var voiceEnabled = true
    @State private var showRestoreConfirm = false

    /// All intelligence routes in display order (IntelligenceRoute isn't CaseIterable).
    private let routes: [IntelligenceRoute] = [.onDevice, .cloud, .mock]

    /// Local-notification helper + the stable id for the daily review reminder.
    private let notifications = NotificationService()
    private static let reminderID = "db.dailyReview"

    private var accountType: AccountType { AccountType(rawValue: accountTypeRaw) ?? .none }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("账号", systemImage: "person.crop.circle.fill")
            accountRow

            DBSectionHeader("智能", systemImage: "sparkles")
            aiModelRow

            DBSectionHeader("设置", systemImage: "gearshape.fill")

            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                VStack(alignment: .leading, spacing: DBSpacing.md) {
                    appearanceSetting
                    ProfileRowDivider()
                    voiceSetting
                    ProfileRowDivider()
                    notificationSetting
                    ProfileRowDivider()
                    routeSetting
                    ProfileRowDivider()
                    learnModeSetting
                }
            }

            // 数据管理
            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                Button {
                    showRestoreConfirm = true
                } label: {
                    HStack(spacing: DBSpacing.md) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.dbBody)
                            .foregroundStyle(Color.dbError)
                            .frame(width: 34, height: 34)
                            .background(Color.dbErrorSoft, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("恢复示例数据")
                                .font(.dbBody)
                                .foregroundStyle(Color.dbTextPrimary)
                            Text("清空并重置为出厂示例内容")
                                .font(.dbCaption)
                                .foregroundStyle(Color.dbTextSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.dbFootnote.weight(.semibold))
                            .foregroundStyle(Color.dbTextTertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, DBSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { voiceEnabled = tts.enabled }
        .confirmationDialog(
            "确定要恢复示例数据吗？",
            isPresented: $showRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("恢复示例数据", role: .destructive) {
                onRestoreSampleData()
                voiceEnabled = tts.enabled
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会清空当前的错题、历史与设置，并重新载入示例内容。此操作不可撤销。")
        }
    }

    // MARK: Appearance

    private var appearanceSetting: some View {
        let current = ProfileAppearance(rawValue: appearanceRaw) ?? .system
        return VStack(alignment: .leading, spacing: DBSpacing.sm) {
            HStack {
                settingLabel(title: "外观", systemImage: "paintbrush.fill", tint: .dbPrimary)
                Spacer(minLength: 0)
                Image(systemName: current.symbol)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Picker("外观", selection: Binding(
                get: { current },
                set: { appearanceRaw = $0.rawValue }
            )) {
                ForEach(ProfileAppearance.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Voice

    private var voiceSetting: some View {
        Toggle(isOn: Binding(
            get: { voiceEnabled },
            set: { newValue in
                voiceEnabled = newValue
                tts.enabled = newValue
                if newValue {
                    tts.speak("语音播报已开启")
                } else {
                    tts.stop()
                }
                HapticEngine.play(.selection)
            }
        )) {
            settingLabel(
                title: "语音播报",
                systemImage: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                tint: .dbSecondary,
                subtitle: "讲解、听写与跟读的朗读声音"
            )
        }
        .tint(Color.dbPrimary)
    }

    // MARK: Intelligence route

    private var routeSetting: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            HStack {
                settingLabel(
                    title: "智能来源",
                    systemImage: "cpu.fill",
                    tint: .dbInfo,
                    subtitle: "优先使用的解题与讲解通道"
                )
                Spacer(minLength: 0)
                DBRouteBadge(profile.preferredRoute)
            }
            Picker("智能来源", selection: Binding(
                get: { profile.preferredRoute },
                set: { profile.preferredRoute = $0 }
            )) {
                ForEach(routes, id: \.rawValue) { route in
                    Text(route.badgeLabel).tag(route)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Learn mode

    private var learnModeSetting: some View {
        Toggle(isOn: $profile.learnModeEnabled) {
            settingLabel(
                title: "学习模式",
                systemImage: "graduationcap.fill",
                tint: .dbSuccess,
                subtitle: "引导式讲解、先思路后答案，防止直接抄答案"
            )
        }
        .tint(Color.dbPrimary)
    }

    // MARK: Account (F53)

    /// Pushes the dedicated account screen (Sign in with Apple / 游客模式). Shows
    /// the current account state as a trailing chip so the row reads at a glance.
    private var accountRow: some View {
        NavigationLink {
            AccountView()
        } label: {
            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                HStack(spacing: DBSpacing.md) {
                    Image(systemName: accountType.chipSymbol)
                        .font(.dbBody)
                        .foregroundStyle(accountType.chipTint)
                        .frame(width: 34, height: 34)
                        .background(accountType.chipTint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("账号")
                            .font(.dbBody)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text(accountType == .apple ? "已登录，可多设备同步" : "登录后可在多台设备同步学习记录")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Spacer(minLength: 0)
                    Text(accountType.chipTitle)
                        .font(.dbFootnote.weight(.medium))
                        .foregroundStyle(Color.dbTextSecondary)
                    Image(systemName: "chevron.right")
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(Color.dbTextTertiary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, DBSpacing.xs)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: AI model (multi-provider)

    /// Pushes the cloud-AI provider/model picker. Subtitle reflects the live
    /// selection (`AICredentialStore.statusSummary`).
    private var aiModelRow: some View {
        NavigationLink {
            AISettingsView()
        } label: {
            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                HStack(spacing: DBSpacing.md) {
                    Image(systemName: ai.cloudEnabled ? "sparkles" : "cpu")
                        .font(.dbBody)
                        .foregroundStyle(ai.cloudEnabled ? Color.dbPrimary : Color.dbTextSecondary)
                        .frame(width: 34, height: 34)
                        .background((ai.cloudEnabled ? Color.dbPrimary : Color.dbTextSecondary).opacity(0.14),
                                   in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AI 模型")
                            .font(.dbBody)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text(ai.statusSummary)
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if ai.cloudEnabled {
                        Text("增强")
                            .font(.dbCaption2.weight(.semibold))
                            .foregroundStyle(Color.dbPrimary)
                            .padding(.horizontal, DBSpacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.dbPrimarySoft, in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(Color.dbTextTertiary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, DBSpacing.xs)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Notifications (F13b)

    private var notificationSetting: some View {
        Toggle(isOn: Binding(
            get: { notificationsEnabled },
            set: { newValue in
                notificationsEnabled = newValue
                HapticEngine.play(.selection)
                if newValue {
                    Task {
                        let granted = await notifications.requestAuthorization()
                        if granted {
                            await notifications.scheduleDaily(
                                id: Self.reminderID,
                                title: "该复习啦",
                                body: "今天有错题和单词在等你巩固，3 分钟搞定～",
                                hour: 19, minute: 30
                            )
                        } else {
                            // Authorization denied — reflect reality in the toggle.
                            notificationsEnabled = false
                        }
                    }
                } else {
                    notifications.cancel(id: Self.reminderID)
                }
            }
        )) {
            settingLabel(
                title: "每日提醒",
                systemImage: notificationsEnabled ? "bell.badge.fill" : "bell.slash.fill",
                tint: .dbWarning,
                subtitle: "每天 19:30 提醒复习错题与单词"
            )
        }
        .tint(Color.dbPrimary)
    }

    // MARK: Shared label

    private func settingLabel(title: String, systemImage: String, tint: Color, subtitle: String? = nil) -> some View {
        HStack(spacing: DBSpacing.md) {
            Image(systemName: systemImage)
                .font(.dbBody)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                }
            }
        }
    }
}

// MARK: - Footer

struct ProfileFooter: View {
    var body: some View {
        VStack(spacing: DBSpacing.xs) {
            DBMascot(mood: .cheering, size: 48)
            Text("豆包爱学 · 陪你每天进步一点点")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
            Text("无广告 · 无会员 · 全部功能免费")
                .font(.dbCaption2)
                .foregroundStyle(Color.dbTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DBSpacing.sm)
        .padding(.bottom, DBSpacing.lg)
    }
}

#Preview("Settings") {
    ScrollView {
        ProfileSettingsCard(
            profile: ProfilePreviewData.sampleProfile,
            onRestoreSampleData: {}
        )
        .padding(DBSpacing.screenInset)
    }
    .background(Color.dbBackground)
    .environment(TTSService())
    .environment(AICredentialStore())
}
