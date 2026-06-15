//
//  ProfileHeaderCard.swift
//  豆包爱学 — Features/Profile
//
//  Profile header (avatar + nickname + grade badge, editable) and the stats
//  summary row used at the top of the personal center.
//

import SwiftUI

// MARK: - Header

struct ProfileHeaderCard: View {
    let profile: LearnerProfile?
    let onEdit: () -> Void

    private var nickname: String { profile?.nickname ?? "小学员" }
    private var subjects: [Subject] { profile?.subjects ?? [] }

    var body: some View {
        DBCard(padding: DBSpacing.lg, fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.lg) {
                    DBAvatar(
                        name: nickname,
                        size: 68,
                        gradeBadge: profile?.grade.displayName
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(nickname)
                            .font(.dbTitle2)
                            .foregroundStyle(Color.dbTextPrimary)
                        HStack(spacing: DBSpacing.xs) {
                            Text(profile?.stage.displayName ?? "学段未设置")
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextSecondary)
                            Text("·")
                                .foregroundStyle(Color.dbTextTertiary)
                            DBStreakView(days: profile?.streakDays ?? 0)
                        }
                    }

                    Spacer(minLength: 0)

                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .font(.dbHeadline)
                            .foregroundStyle(Color.dbPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.dbPrimarySoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("编辑年级与学科")
                }

                if !subjects.isEmpty {
                    DBFlowLayout(spacing: DBSpacing.xs) {
                        ForEach(subjects) { subject in
                            DBSubjectChip(subject, isSelected: true)
                        }
                    }
                } else {
                    Button(action: onEdit) {
                        Label("设置你的学科与教材版本", systemImage: "plus.circle.fill")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Stats row

struct ProfileStatsCard: View {
    let solved: Int
    let streakDays: Int
    let averageMastery: Double

    private var masteryPercent: Int { Int((averageMastery * 100).rounded()) }
    private var masteryTint: Color {
        switch averageMastery {
        case ..<0.5: .dbWarning
        case ..<0.85: .dbSecondary
        default: .dbSuccess
        }
    }

    var body: some View {
        DBCard(fill: .dbSurface, elevation: .low) {
            HStack(spacing: 0) {
                DBValueStat(
                    value: "\(solved)",
                    caption: "已解题",
                    systemImage: "checkmark.seal.fill",
                    tint: .dbPrimary
                )
                statDivider
                DBValueStat(
                    value: "\(streakDays)",
                    caption: "连续天数",
                    systemImage: "flame.fill",
                    tint: .dbAccent
                )
                statDivider
                DBValueStat(
                    value: "\(masteryPercent)%",
                    caption: "平均掌握",
                    systemImage: "chart.pie.fill",
                    tint: masteryTint
                )
            }
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.dbSeparator)
            .frame(width: 1, height: 34)
    }
}

#Preview("Header + Stats") {
    ScrollView {
        VStack(spacing: DBSpacing.lg) {
            ProfileHeaderCard(
                profile: ProfilePreviewData.sampleProfile,
                onEdit: {}
            )
            ProfileStatsCard(solved: 128, streakDays: 7, averageMastery: 0.62)
        }
        .padding(DBSpacing.screenInset)
    }
    .background(Color.dbBackground)
}
