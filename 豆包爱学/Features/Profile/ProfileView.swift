//
//  ProfileView.swift
//  豆包爱学 — Features/Profile
//
//  我的 (个人中心) · RESEARCH F54 / F56.
//  A SwiftData-backed personal center: profile header (avatar + grade badge,
//  editable grade/subjects), a stats row with a weekly-minutes Swift Charts
//  summary, grouped navigation rows (历史记录 / 收藏 / 下载 / 错题本 / 学习报告 /
//  家长模式), and a Settings section (appearance, voice, 智能来源, 学习模式,
//  恢复示例数据). Fully adaptive (iPhone / iPad / Mac) and dark-mode native.
//
//  Contract: `struct ProfileView: View` with a no-arg `init()`.
//

import SwiftUI
import SwiftData
import Charts

struct ProfileView: View {
    // Live profile (single learner). Seeded by SampleData on first run.
    @Query private var profiles: [LearnerProfile]
    // Stats sources.
    @Query private var masteryRecords: [MasteryRecord]
    @Query(sort: \ActivityLog.date, order: .reverse) private var activity: [ActivityLog]
    // History / collection counts.
    @Query(sort: \ProblemRecord.createdAt, order: .reverse) private var problems: [ProblemRecord]
    @Query private var mistakes: [MistakeItem]
    @Query private var documents: [DocumentEntity]
    @Query private var conversations: [Conversation]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(TTSService.self) private var tts
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Appearance preference (shared with the Settings card), applied to this
    // screen and any sheet it presents.
    @AppStorage("db.appearance") private var appearanceRaw: String = ProfileAppearance.system.rawValue

    @State private var editingProfile = false

    private var profile: LearnerProfile? { profiles.first }
    private var isRegular: Bool { sizeClass != .compact }

    // MARK: Derived stats

    /// Average mastery across all tracked knowledge points (0…1).
    private var averageMastery: Double {
        guard !masteryRecords.isEmpty else { return 0 }
        let total = masteryRecords.reduce(0.0) { $0 + $1.score }
        return total / Double(masteryRecords.count)
    }

    private var solvedCount: Int {
        // Prefer the live problem history; fall back to the profile counter.
        max(problems.count, profile?.problemsSolved ?? 0)
    }

    private var savedCount: Int {
        problems.filter { $0.savedToMistakes }.count + mistakes.count
    }

    private var downloadCount: Int {
        documents.count + conversations.count
    }

    var body: some View {
        Group {
            if let profile {
                loadedContent(profile)
            } else {
                // Onboarding prompt (RESEARCH F54 "prompt to set grade/log in"):
                // create a profile then open the editor.
                DBStateView(
                    kind: .empty,
                    title: "完善你的学习档案",
                    message: "设置你的年级与学科，豆包就能为你定制学习内容啦～",
                    retry: { createProfileAndEdit() }
                )
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("我的")
        .preferredColorScheme((ProfileAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
        .sheet(isPresented: $editingProfile) {
            if let profile {
                ProfileEditSheet(profile: profile)
            }
        }
    }

    @ViewBuilder
    private func loadedContent(_ profile: LearnerProfile) -> some View {
        ScrollView {
            VStack(spacing: DBSpacing.lg) {
                ProfileHeaderCard(
                    profile: profile,
                    onEdit: { editingProfile = true }
                )

                ProfileStatsCard(
                    solved: solvedCount,
                    streakDays: profile.streakDays,
                    averageMastery: averageMastery
                )

                WeeklyActivityCard(logs: activity)

                achievementsEntry

                ProfileNavigationGroup(
                    historyCount: solvedCount,
                    favoriteCount: savedCount,
                    downloadCount: downloadCount,
                    mistakeCount: mistakes.count,
                    onHistory: { openMistakes() },
                    onFavorites: { openMistakes() },
                    onDownloads: { router.navigate(.tool(.documentQA), regular: isRegular) },
                    onMistakes: { openMistakes() },
                    onReports: { router.navigate(.reports, regular: isRegular) },
                    onParentMode: { router.present(.parentGate(reason: "进入家长模式需先完成家长验证，开启隐藏答案与时间管理。")) }
                )

                ProfileSettingsCard(
                    profile: profile,
                    onRestoreSampleData: restoreSampleData
                )

                ProfileFooter()
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    /// Entry into the 成就 wall (XP, level, streak heat-strip, badge gallery).
    private var achievementsEntry: some View {
        Button {
            HapticEngine.play(.selection)
            router.navigate(.achievements, regular: isRegular)
        } label: {
            DBCard(fill: .dbPrimarySoft, elevation: .none) {
                HStack(spacing: DBSpacing.md) {
                    Image(systemName: "trophy.fill")
                        .font(.dbTitle3)
                        .foregroundStyle(Color.dbPrimaryDeep)
                        .frame(width: 40, height: 40)
                        .background(Color.dbAccentSoft, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("我的成就")
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text("XP 等级 · 连续打卡 · 徽章墙")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("我的成就：查看经验等级、连续打卡与徽章")
    }

    // MARK: Actions

    /// Route to 错题本. On iPad/Mac this is a dedicated sidebar section; on
    /// iPhone it is reached as a tool push.
    private func openMistakes() {
        if isRegular {
            router.sidebarSelection = .mistakes
        } else {
            router.navigate(.tool(.mistakeNotebook), regular: false)
        }
    }

    private func restoreSampleData() {
        SampleData.reset(modelContext)
        HapticEngine.play(.success)
        // Refresh the voice toggle to its seeded default.
        tts.enabled = true
    }

    /// First-launch / post-reset path: insert a fresh learner profile and open
    /// the editor so the user can personalize grade & subjects immediately.
    private func createProfileAndEdit() {
        let newProfile = LearnerProfile()
        modelContext.insert(newProfile)
        modelContext.saveLogging()
        HapticEngine.play(.light)
        editingProfile = true
    }
}

#Preview("个人中心") {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(ProfilePreviewData.container)
    .environment(AppRouter())
    .environment(TTSService())
    .environment(AICredentialStore())
}
