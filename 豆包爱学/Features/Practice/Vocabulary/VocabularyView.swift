//
//  VocabularyView.swift
//  豆包爱学 — Features/Practice/Vocabulary
//
//  背单词 (RESEARCH F35). Entry point wired to `ToolKind.vocabulary`. A textbook-
//  synced list of `WordDeck`s (seeded via @Query) each showing a 待复习 due-count
//  badge and a mastery progress bar, plus a hero "今日复习" entry that gathers all
//  cards due today across every deck. Tapping a deck pushes `WordDeckReviewView`;
//  tapping 今日复习 pushes the deck that currently has the most due cards (so the
//  one tap always lands on real work). All empty/all-caught-up states handled.
//
//  Pushed view: no NavigationStack here — sets .navigationTitle and returns
//  content. Full Dark Mode via semantic Color.db*; both platforms supported.
//

import SwiftUI
import SwiftData

struct VocabularyView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \WordDeck.createdAt, order: .forward) private var decks: [WordDeck]

    init() {}

    private var isRegular: Bool { sizeClass != .compact }

    /// Total cards due today across every deck (forgetting-curve queue size).
    private var totalDue: Int {
        decks.reduce(0) { $0 + $1.dueCount }
    }

    /// The deck with the most due cards — the target of the 今日复习 hero button.
    private var mostUrgentDeck: WordDeck? {
        decks.filter { $0.dueCount > 0 }.max { $0.dueCount < $1.dueCount }
    }

    var body: some View {
        Group {
            if decks.isEmpty {
                DBStateView(kind: .empty,
                            title: "还没有单词本",
                            message: "课本单元的单词本会同步到这里，背单词、做小测，掌握度自动记录。",
                            systemImage: "character.book.closed.fill")
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("背单词")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                todayCard
                DBSectionHeader("我的单词本",
                                subtitle: "共 \(decks.count) 本 · 点开任意一本开始背记",
                                systemImage: "books.vertical.fill")
                VStack(spacing: DBSpacing.md) {
                    ForEach(decks) { deck in
                        deckRow(deck)
                    }
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 今日复习 hero

    private var todayCard: some View {
        DBCard(fill: .clear, elevation: .medium) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(alignment: .top, spacing: DBSpacing.md) {
                    DBMascot(mood: totalDue > 0 ? .cheering : .happy, size: 60)
                    VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                        Text("今日复习")
                            .font(.dbTitle3)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text(todaySubtitle)
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Spacer()
                    if totalDue > 0 {
                        VStack(spacing: 0) {
                            Text("\(totalDue)")
                                .font(.dbScore.monospacedDigit())
                                .foregroundStyle(Color.dbPrimaryDeep)
                            Text("张待复习")
                                .font(.dbCaption2)
                                .foregroundStyle(Color.dbTextTertiary)
                        }
                    }
                }

                if totalDue > 0, let target = mostUrgentDeck {
                    Button {
                        HapticEngine.play(.light)
                        router.navigate(.wordDeck(target.id), regular: isRegular)
                    } label: {
                        Label("开始复习（\(totalDue) 张）", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.db(.primary, fullWidth: true))
                } else {
                    Label("今天的单词都复习完啦，明天见！", systemImage: "checkmark.seal.fill")
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbSuccess)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DBSpacing.xs)
                }
            }
            .padding(DBSpacing.xs)
        }
        .background(
            RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                .fill(Color.dbHeroGradient.opacity(0.18))
        )
    }

    private var todaySubtitle: String {
        if totalDue > 0 {
            return "根据遗忘曲线，今天有 \(totalDue) 张卡片到了复习时间。"
        } else {
            return "保持每天背一点，记得更牢。"
        }
    }

    // MARK: - Deck row

    private func deckRow(_ deck: WordDeck) -> some View {
        Button {
            HapticEngine.play(.selection)
            router.navigate(.wordDeck(deck.id), regular: isRegular)
        } label: {
            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    HStack(alignment: .top, spacing: DBSpacing.md) {
                        deckIcon(deck)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deck.name.isEmpty ? "单词本" : deck.name)
                                .font(.dbHeadline)
                                .foregroundStyle(Color.dbTextPrimary)
                                .lineLimit(2)
                            HStack(spacing: DBSpacing.xs) {
                                DBSubjectChip(deck.subject)
                                Text(deck.grade.displayName)
                                    .font(.dbCaption2)
                                    .foregroundStyle(Color.dbTextTertiary)
                            }
                        }
                        Spacer(minLength: DBSpacing.sm)
                        if deck.dueCount > 0 {
                            DBBadge(count: deck.dueCount, tint: .dbPrimary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.dbFootnote.weight(.semibold))
                            .foregroundStyle(Color.dbTextTertiary)
                    }

                    deckStats(deck)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func deckIcon(_ deck: WordDeck) -> some View {
        let tint = DBSubjectColor.color(for: deck.subject)
        return Image(systemName: "character.book.closed.fill")
            .font(.dbTitle3)
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
    }

    @ViewBuilder
    private func deckStats(_ deck: WordDeck) -> some View {
        let stats = DeckStats(deck: deck)
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            HStack(spacing: DBSpacing.sm) {
                statLabel(symbol: "rectangle.stack.fill", text: "\(stats.total) 词", tint: .dbSecondary)
                statLabel(symbol: VocabPresentation.masterySymbol(.mastered),
                          text: "已掌握 \(stats.mastered)", tint: .dbSuccess)
                if stats.due > 0 {
                    statLabel(symbol: "bell.badge.fill", text: "待复习 \(stats.due)", tint: .dbPrimary)
                }
            }
            ProgressView(value: stats.masteryProgress)
                .tint(.dbSuccess)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
    }

    private func statLabel(symbol: String, text: String, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.dbCaption2.weight(.medium))
            .foregroundStyle(tint)
    }
}

// MARK: - Deck stats (pure)

/// Aggregated counts for a deck used by the list row. Pure value type so the row
/// stays declarative and the numbers are computed once.
private struct DeckStats {
    let total: Int
    let mastered: Int
    let due: Int

    init(deck: WordDeck) {
        let cards = deck.cards ?? []
        total = cards.count
        mastered = cards.filter { $0.mastery == .mastered }.count
        due = deck.dueCount
    }

    /// Share of cards mastered, 0…1 (0 when the deck is empty).
    var masteryProgress: Double {
        guard total > 0 else { return 0 }
        return Double(mastered) / Double(total)
    }
}

// MARK: - Preview

#Preview("背单词") {
    NavigationStack {
        VocabularyView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
