//
//  CompanionView.swift
//  豆包爱学 — Features/Companion
//
//  AI 伙伴 hub (RESEARCH F23/F24/F28). A list of saved Conversation threads with
//  a 学习问答 ↔ 成长挚友 mode toggle and a "新对话" action. The two modes share
//  one chat engine but differ in theme and copy. Tapping a thread pushes the
//  resumable ConversationView (接续学习).
//
//  Contract: `struct CompanionView: View` with `init()`.
//  Wired to `AppSection.companion` and `ToolKind.knowledgeQA`.
//

import SwiftUI
import SwiftData

struct CompanionView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Newest-first; we split into the active mode in `filtered`.
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query private var profiles: [LearnerProfile]

    @State private var mode: CompanionMode = .knowledge
    @State private var searchText: String = ""

    private var isRegular: Bool { sizeClass != .compact }
    private var profile: LearnerProfile? { profiles.first }
    private var accent: Color { CompanionTheme.accent(for: mode) }

    /// Conversations belonging to the active mode, with optional search filtering.
    /// `tutor`-kind threads (from 拍题答疑) surface under 学习问答 too.
    private var filtered: [Conversation] {
        let inMode = conversations.filter { convo in
            switch mode {
            case .knowledge: convo.kindRaw == "knowledge" || convo.kindRaw == "tutor"
            case .companion: convo.kindRaw == "companion"
            }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return inMode }
        return inMode.filter { convo in
            convo.title.localizedCaseInsensitiveContains(trimmed)
                || convo.sortedMessages.contains { $0.text.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                hero
                modePicker
                DBSearchField(text: $searchText, placeholder: "搜索历史对话…")

                if filtered.isEmpty {
                    emptyState
                } else {
                    DBSectionHeader(mode == .companion ? "聊天记录" : "历史提问",
                                    subtitle: "可随时接续上次的对话",
                                    systemImage: "clock.arrow.circlepath")
                    LazyVStack(spacing: DBSpacing.cardGap) {
                        ForEach(filtered) { convo in
                            Button {
                                router.navigate(.conversation(convo.id), regular: isRegular)
                            } label: {
                                ConversationRow(conversation: convo, accent: accent)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(convo)
                                } label: {
                                    Label("删除对话", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(DBSpacing.screenInset)
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
        .background(Color.dbBackground)
        .navigationTitle("AI 伙伴")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    startNewConversation()
                } label: {
                    Label("新对话", systemImage: "square.and.pencil")
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        DBCard(fill: CompanionTheme.accentSoft(for: mode), elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: CompanionTheme.mascotMood(for: mode), size: 64)
                VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                    Text(mode == .companion ? "我是你的成长挚友" : "我是你的知识搭子")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text(mode.subtitle)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        startNewConversation()
                    } label: {
                        Label(mode == .companion ? "找豆包聊聊" : "开始提问", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.dbFootnote.weight(.semibold))
                    }
                    .buttonStyle(.db(.secondary))
                    .tint(accent)
                    .padding(.top, DBSpacing.xxs)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Mode picker

    private var modePicker: some View {
        HStack(spacing: DBSpacing.sm) {
            ForEach(CompanionMode.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = item }
                    HapticEngine.play(.selection)
                } label: {
                    VStack(spacing: DBSpacing.xxs) {
                        Label(item.title, systemImage: item.symbolName)
                            .font(.dbSubheadline.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                        Text(item.subtitle)
                            .font(.dbCaption2)
                            .foregroundStyle(mode == item ? Color.dbOnPrimary.opacity(0.9) : Color.dbTextTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DBSpacing.md)
                    .foregroundStyle(mode == item ? Color.dbOnPrimary : Color.dbTextSecondary)
                    .background {
                        RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                            .fill(mode == item ? CompanionTheme.accent(for: item) : Color.dbSurface)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                            .strokeBorder(Color.dbSeparator, lineWidth: mode == item ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == item ? [.isSelected] : [])
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: DBSpacing.lg) {
            DBStateView(
                kind: .empty,
                title: searchText.isEmpty
                    ? (mode == .companion ? "还没有聊天记录" : "还没有提问记录")
                    : "没有找到相关对话",
                message: searchText.isEmpty
                    ? (mode == .companion
                        ? "心里有什么想说的，随时来找豆包～"
                        : "好奇什么都可以问，豆包陪你一步步想清楚。")
                    : "换个关键词试试看吧。"
            )

            if searchText.isEmpty {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    Text("试试这样开始")
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(Color.dbTextSecondary)
                    DBFlowLayout(spacing: DBSpacing.sm) {
                        ForEach(mode.listExamplePrompts, id: \.self) { prompt in
                            Button {
                                startNewConversation(seed: prompt)
                            } label: {
                                DBChip(prompt, systemImage: "sparkles", tint: accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, DBSpacing.lg)
    }

    // MARK: Actions

    /// Create a new thread for the active mode and push it. An optional `seed`
    /// prefilled prompt is carried via the conversation title so the detail view
    /// can offer it as a starting message.
    private func startNewConversation(seed: String? = nil) {
        let convo = Conversation()
        convo.kindRaw = mode.conversationKindRaw
        convo.title = seed.map { String($0.prefix(18)) } ?? mode.defaultTitle
        convo.subject = profile?.subjects.first
        convo.createdAt = .now
        convo.updatedAt = .now
        modelContext.insert(convo)
        modelContext.saveLogging()
        HapticEngine.play(.light)
        router.navigate(.conversation(convo.id), regular: isRegular)
    }

    private func delete(_ convo: Conversation) {
        modelContext.delete(convo)
        modelContext.saveLogging()
        HapticEngine.play(.light)
    }
}

// MARK: - Conversation row

private struct ConversationRow: View {
    let conversation: Conversation
    let accent: Color

    private var lastMessage: ChatMessageEntity? { conversation.sortedMessages.last }
    private var preview: String {
        guard let last = lastMessage else { return "新的对话，点开开始聊吧～" }
        let text = last.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        // Streaming/rich replies may have empty `.text`; fall back to blocks.
        let blockText = last.blocks.first(where: { $0.kind == .text })?.content ?? ""
        return blockText.isEmpty ? "（多媒体内容）" : blockText
    }
    private var mode: CompanionMode { CompanionMode(conversationKindRaw: conversation.kindRaw) }

    var body: some View {
        DBCard {
            HStack(spacing: DBSpacing.md) {
                ZStack {
                    Circle().fill(accent.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: mode.symbolName)
                        .font(.dbHeadline)
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                    HStack(spacing: DBSpacing.xs) {
                        Text(conversation.title)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(1)
                        if let subject = conversation.subject {
                            DBTag(subject.displayName, tint: DBSubjectColor.color(for: subject))
                        }
                    }
                    Text(preview)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: DBSpacing.xs)

                VStack(alignment: .trailing, spacing: DBSpacing.xxs) {
                    Text(conversation.updatedAt.formatted(date: .omitted, time: .shortened))
                        .font(.dbCaption2)
                        .foregroundStyle(Color.dbTextTertiary)
                    Image(systemName: "chevron.right")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
        }
    }
}

#Preview("AI 伙伴") {
    NavigationStack {
        CompanionView()
    }
    .environment(AppRouter())
    .environment(TTSService())
    .modelContainer(for: [Conversation.self, ChatMessageEntity.self, LearnerProfile.self], inMemory: true)
}
