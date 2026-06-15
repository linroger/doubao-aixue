//
//  ProfileNavigationGroup.swift
//  豆包爱学 — Features/Profile
//
//  Grouped, warm navigation rows: 历史记录 / 收藏 / 下载 / 错题本 / 学习报告 /
//  家长模式. Each row carries an icon, tint, optional count badge, and a
//  chevron, grouped inside DBCard surfaces.
//

import SwiftUI

/// A single tappable navigation row used inside grouped profile cards.
struct ProfileRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    var subtitle: String? = nil
    var badge: Int? = nil
    var accessory: ProfileRowAccessory = .chevron
    let action: () -> Void

    enum ProfileRowAccessory {
        case chevron
        case lock
    }

    var body: some View {
        Button(action: action) {
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

                Spacer(minLength: DBSpacing.sm)

                if let badge, badge > 0 {
                    Text(badge > 999 ? "999+" : "\(badge)")
                        .font(.dbFootnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.dbTextSecondary)
                }

                Image(systemName: accessory == .lock ? "lock.fill" : "chevron.right")
                    .font(.dbFootnote.weight(.semibold))
                    .foregroundStyle(Color.dbTextTertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, DBSpacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

/// Thin inset separator between rows in a grouped card.
struct ProfileRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.dbSeparator)
            .frame(height: 1)
            .padding(.leading, 34 + DBSpacing.md)
    }
}

struct ProfileNavigationGroup: View {
    let historyCount: Int
    let favoriteCount: Int
    let downloadCount: Int
    let mistakeCount: Int

    let onHistory: () -> Void
    let onFavorites: () -> Void
    let onDownloads: () -> Void
    let onMistakes: () -> Void
    let onReports: () -> Void
    let onParentMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            // 我的内容
            DBSectionHeader("我的内容", systemImage: "tray.full.fill")
            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                VStack(spacing: 0) {
                    ProfileRow(
                        title: "历史记录",
                        systemImage: "clock.arrow.circlepath",
                        tint: .dbInfo,
                        subtitle: "拍题与答疑的解题记录",
                        badge: historyCount,
                        action: onHistory
                    )
                    ProfileRowDivider()
                    ProfileRow(
                        title: "收藏",
                        systemImage: "star.fill",
                        tint: .dbWarning,
                        subtitle: "标记的好题与讲解",
                        badge: favoriteCount,
                        action: onFavorites
                    )
                    ProfileRowDivider()
                    ProfileRow(
                        title: "下载",
                        systemImage: "arrow.down.circle.fill",
                        tint: .dbSecondary,
                        subtitle: "离线文档与对话",
                        badge: downloadCount,
                        action: onDownloads
                    )
                    ProfileRowDivider()
                    ProfileRow(
                        title: "错题本",
                        systemImage: "book.closed.fill",
                        tint: .dbPrimary,
                        subtitle: "自动收录，按知识点复习",
                        badge: mistakeCount,
                        action: onMistakes
                    )
                }
            }

            // 学习与陪伴
            DBSectionHeader("学习与陪伴", systemImage: "sparkles")
            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                VStack(spacing: 0) {
                    ProfileRow(
                        title: "学习报告",
                        systemImage: "chart.bar.xaxis",
                        tint: .dbAccent,
                        subtitle: "掌握度趋势与薄弱点预警",
                        action: onReports
                    )
                    ProfileRowDivider()
                    ProfileRow(
                        title: "家长模式",
                        systemImage: "figure.2.and.child.holdinghands",
                        tint: .dbSuccess,
                        subtitle: "隐藏答案 · 时间管理 · 学情周报",
                        accessory: .lock,
                        action: onParentMode
                    )
                }
            }
        }
    }
}

#Preview("Navigation group") {
    ScrollView {
        ProfileNavigationGroup(
            historyCount: 128,
            favoriteCount: 12,
            downloadCount: 4,
            mistakeCount: 23,
            onHistory: {}, onFavorites: {}, onDownloads: {},
            onMistakes: {}, onReports: {}, onParentMode: {}
        )
        .padding(DBSpacing.screenInset)
    }
    .background(Color.dbBackground)
}
