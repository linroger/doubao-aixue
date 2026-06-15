//
//  DictationView.swift
//  豆包爱学 — Features/Practice/Dictation
//
//  听写 (RESEARCH F-dictation): browse the seeded dictation lists (语文词语 / English
//  spelling), pick one, then run a read-aloud → 默写 → 批改 session. The teacher
//  reads each entry aloud (TTSService, zh-CN / en-US) with speed / 间隔 / 重复 /
//  上一个 / 下一个 / 自动播放 controls; the child writes (typed, plus PencilKit +
//  on-device OCR on iOS); intelligence.gradeDictation diffs every word and we show
//  a per-word ✓/✗ list, an accuracy ring, 重测错词, persist a DictationResult, and
//  fold每个错字 into the 错题本.
//
//  Wired to ToolKind.dictation. Entry init is `DictationView()`.
//

import SwiftUI
import SwiftData

struct DictationView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \DictationList.createdAt, order: .forward) private var lists: [DictationList]

    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        Group {
            if lists.isEmpty {
                DBStateView(kind: .empty,
                            title: "还没有听写表",
                            message: "老师或家长添加听写词表后，就能在这里开始练习啦。",
                            systemImage: "ear.badge.waveform")
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("听写")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                header
                DBSectionHeader("选择听写表", subtitle: "点一张词表，豆包老师来念给你听")
                ForEach(lists) { list in
                    Button {
                        router.navigate(.dictation(list.id), regular: isRegular)
                    } label: {
                        DictationListCard(list: list)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private var header: some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: .cheering, size: 64)
            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                Text("一起来听写吧")
                    .font(.dbTitle3)
                    .foregroundStyle(Color.dbOnPrimary)
                Text("听一遍、写一遍，错的字我们再练一次。")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbOnPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbHeroGradient)
        .clipShape(RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        .dbShadow(.low)
    }
}

// MARK: - List card

private struct DictationListCard: View {
    let list: DictationList

    var body: some View {
        DBCard {
            HStack(spacing: DBSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                        .fill(DBSubjectColor.color(for: list.language).opacity(0.16))
                    Image(systemName: list.language == .english ? "textformat.abc" : "character.book.closed")
                        .font(.dbTitle3)
                        .foregroundStyle(DBSubjectColor.color(for: list.language))
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text(list.name.isEmpty ? "听写词表" : list.name)
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                        .lineLimit(1)
                    HStack(spacing: DBSpacing.sm) {
                        DBTag(list.language == .english ? "英语" : "语文",
                              tint: DBSubjectColor.color(for: list.language))
                        if !list.unit.isEmpty {
                            DBTag(list.unit, tint: .dbSecondary)
                        }
                        Text("\(list.entries.count) 个词")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextTertiary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextTertiary)
            }
        }
    }
}

#Preview {
    NavigationStack { DictationView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
