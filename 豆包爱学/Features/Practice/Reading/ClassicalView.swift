//
//  ClassicalView.swift
//  豆包爱学 — Features/Practice/Reading
//
//  古诗文 (RESEARCH): browse the bundled 古诗文 catalog, then study each piece
//  with 原文 / 译文 / 赏析, an author card, 断句 (tap a clause to read it aloud),
//  full 朗读 (TTS), and 与作者对话 (hands off to the tutor sheet). Wired to
//  `ToolKind.classical` via `init()`.
//
//  All states handled (empty catalog → DBStateView); full Dark Mode via
//  semantic Color.db*; both platforms supported (TTS is on-device on each).
//

import SwiftUI
import SwiftData

// MARK: - List

struct ClassicalView: View {
    @State private var query: String = ""
    @State private var selected: CatalogPoem?

    private let poems = ContentCatalog.poems

    init() {}

    private var filtered: [CatalogPoem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return poems }
        return poems.filter {
            $0.title.contains(trimmed) || $0.author.contains(trimmed)
                || $0.dynasty.contains(trimmed) || $0.original.contains(trimmed)
        }
    }

    var body: some View {
        Group {
            if poems.isEmpty {
                DBStateView(kind: .empty, title: "暂无古诗文",
                            message: "课程内容正在准备中，稍后再来看看吧。")
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("古诗文")
        .navigationDestination(item: $selected) { poem in
            ClassicalStudyView(poem: poem)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSearchField(text: $query, placeholder: "搜索篇目、作者或朝代")

                if filtered.isEmpty {
                    DBStateView(kind: .empty, title: "没有找到",
                                message: "换个关键词试试，比如“李白”或“唐”。")
                        .frame(height: 220)
                } else {
                    ForEach(filtered) { poem in
                        Button { selected = poem } label: { poemRow(poem) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private func poemRow(_ poem: CatalogPoem) -> some View {
        DBCard {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text(poem.title)
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    HStack(spacing: DBSpacing.sm) {
                        DBTag(poem.dynasty.isEmpty ? "古诗文" : poem.dynasty,
                              tint: ReadingPresentation.dynastyTint(poem.dynasty))
                        Text(poem.author)
                            .font(.dbSubheadline)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Text(firstLine(of: poem.original))
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextTertiary)
            }
        }
    }

    private func firstLine(of original: String) -> String {
        ClassicalSegmenter.lines(of: original).first ?? original
    }
}

// MARK: - Study detail

/// Pushed study screen for one piece. Does NOT wrap its own NavigationStack —
/// it is embedded in the shell's stack and just sets a title + returns content.
struct ClassicalStudyView: View {
    let poem: CatalogPoem

    @Environment(AppRouter.self) private var router
    @Environment(TTSService.self) private var tts

    @State private var showSegmentation = false
    @State private var spokenLine: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                authorCard
                originalCard
                translationCard
                appreciationCard
                dialogueCard
            }
            .padding(DBSpacing.screenInset)
        }
        .background(Color.dbBackground)
        .navigationTitle(poem.title)
    }

    // MARK: Author

    private var authorCard: some View {
        HStack(spacing: DBSpacing.md) {
            DBAvatar(name: poem.author, size: 56)
            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                Text(poem.author)
                    .font(.dbTitle2)
                    .foregroundStyle(Color.dbOnPrimary)
                HStack(spacing: DBSpacing.sm) {
                    Text(poem.dynasty.isEmpty ? "古诗文" : poem.dynasty)
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(Color.dbOnPrimary)
                        .padding(.horizontal, DBSpacing.sm)
                        .padding(.vertical, DBSpacing.xxs)
                        .background(Color.dbOnPrimary.opacity(0.22), in: Capsule())
                    Text(poem.grade.displayName)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbOnPrimary.opacity(0.9))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbHeroGradient, in: RoundedRectangle(cornerRadius: DBRadius.lg))
        .dbShadow(.low)
    }

    // MARK: Original + 断句 + 朗读

    private var originalCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("原文", subtitle: showSegmentation ? "点击每个分句可单独朗读" : "可整体朗读，或开启断句逐句读",
                                systemImage: "text.quote") {
                    Button {
                        withAnimation { showSegmentation.toggle() }
                        HapticEngine.play(.selection)
                    } label: {
                        DBChip("断句", systemImage: "scissors", tint: .dbAccent, isSelected: showSegmentation)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(Array(ClassicalSegmenter.lines(of: poem.original).enumerated()), id: \.offset) { _, line in
                    if showSegmentation {
                        segmentedLine(line)
                    } else {
                        Text(line)
                            .font(.dbTitle3)
                            .foregroundStyle(Color.dbTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Button {
                    let body = ClassicalSegmenter.lines(of: poem.original).joined(separator: "，")
                    tts.stop()
                    tts.speak(body, language: "zh-CN", rate: 0.42)
                    HapticEngine.play(.light)
                } label: {
                    Label("朗读全文", systemImage: "play.circle.fill")
                }
                .buttonStyle(.db(.primary, fullWidth: true))

                if tts.isSpeaking {
                    Button { tts.stop() } label: {
                        Label("停止朗读", systemImage: "stop.circle")
                            .font(.dbSubheadline)
                            .foregroundStyle(Color.dbError)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func segmentedLine(_ line: String) -> some View {
        DBFlowLayout(spacing: DBSpacing.xs) {
            ForEach(Array(ClassicalSegmenter.clauses(of: line).enumerated()), id: \.offset) { _, clause in
                Button {
                    spokenLine = clause
                    tts.stop()
                    tts.speak(clause, language: "zh-CN", rate: 0.42)
                    HapticEngine.play(.light)
                } label: {
                    Text(clause)
                        .font(.dbBodyEmph)
                        .foregroundStyle(spokenLine == clause ? Color.dbOnPrimary : Color.dbPrimaryDeep)
                        .padding(.horizontal, DBSpacing.sm)
                        .padding(.vertical, DBSpacing.xs)
                        .background(spokenLine == clause ? Color.dbPrimary : Color.dbPrimarySoft,
                                    in: RoundedRectangle(cornerRadius: DBRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Translation

    private var translationCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("译文", subtitle: "对照理解大意", systemImage: "character.book.closed.fill") {
                    Button {
                        tts.stop()
                        tts.speak(poem.translation, language: "zh-CN")
                        HapticEngine.play(.light)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("朗读译文")
                }
                Text(poem.translation)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextSecondary)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: Appreciation

    private var appreciationCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("赏析", subtitle: "体会写法与情感", systemImage: "sparkles")
                Text(poem.appreciation)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: 与作者对话

    private var dialogueCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.md) {
                    DBMascot(mood: .curious, size: 48)
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text("与作者对话")
                            .font(.dbHeadline)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text("和 \(poem.author) 聊聊这首作品，问问创作时的心境吧。")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Spacer(minLength: 0)
                }

                Button { startDialogue() } label: {
                    Label("开始对话", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(.db(.secondary, fullWidth: true))
            }
        }
    }

    private func startDialogue() {
        let prompt = "我想和\(poem.author)聊聊《\(poem.title)》：这首作品想表达什么？创作时是怎样的心境？"
        router.present(.tutor(problemText: prompt, subject: .chinese, grade: poem.grade))
        HapticEngine.play(.selection)
    }
}

// MARK: - Previews

#Preview("古诗文列表") {
    NavigationStack { ClassicalView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}

#Preview("古诗文学习") {
    NavigationStack {
        ClassicalStudyView(poem: ContentCatalog.poems[0])
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
