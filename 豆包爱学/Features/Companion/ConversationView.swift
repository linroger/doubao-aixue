//
//  ConversationView.swift
//  豆包爱学 — Features/Companion
//
//  A single AI conversation (知识问答 / 成长挚友) with streamed replies, rich
//  blocks, suggestion-chip intents, and resumable history. Wired to
//  Route.conversation(UUID). (Built by the integrator — the companion agent
//  delivered CompanionView + CompanionSupport but disconnected before this file.)
//

import SwiftUI
import SwiftData

struct ConversationView: View {
    let conversationID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.intelligence) private var intelligence
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var conversations: [Conversation]

    @State private var draft: String = ""
    @State private var streamingText: String = ""
    @State private var isStreaming = false
    @State private var streamingTask: Task<Void, Never>?
    @State private var speech = SpeechRecognitionCoordinator()

    init(conversationID: UUID) { self.conversationID = conversationID }

    private var conversation: Conversation? { conversations.first { $0.id == conversationID } }
    private var mode: CompanionMode {
        CompanionMode(conversationKindRaw: conversation?.kindRaw ?? "knowledge")
    }
    private var accent: Color { CompanionTheme.accent(for: mode) }
    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        Group {
            if let conversation {
                chat(conversation)
            } else {
                DBStateView(kind: .empty, title: "对话不存在", message: "它可能已被删除")
            }
        }
        .background(Color.dbBackground)
        .navigationTitle(conversation?.title ?? "对话")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { streamingTask?.cancel() }
    }

    private func chat(_ conversation: Conversation) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DBSpacing.md) {
                        ForEach(conversation.sortedMessages) { message in
                            MessageBubble(message: message, accent: accent) { block in
                                dispatch(block)
                            }
                            .id(message.id)
                        }
                        if isStreaming {
                            StreamingBubble(text: streamingText, accent: accent).id("streaming")
                        }
                    }
                    .padding(DBSpacing.screenInset)
                }
                .onChange(of: conversation.sortedMessages.count) { _, _ in
                    withAnimation { proxy.scrollTo(conversation.sortedMessages.last?.id, anchor: .bottom) }
                }
                .onChange(of: streamingText) { _, _ in
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
            }
            composer(conversation)
        }
    }

    private func composer(_ conversation: Conversation) -> some View {
        HStack(spacing: DBSpacing.sm) {
            Button {
                let said = speech.isListening ? speech.stopListening(simulated: "请帮我讲讲这道题") : { speech.startListening(); return "" }()
                if !said.isEmpty { draft = said }
            } label: {
                Image(systemName: speech.isListening ? "mic.fill" : "mic")
                    .font(.dbTitle3).foregroundStyle(speech.isListening ? accent : Color.dbTextSecondary)
            }
            .buttonStyle(.plain)

            TextField("问问豆包…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.dbBody)
                .lineLimit(1...4)
                .padding(.horizontal, DBSpacing.md)
                .padding(.vertical, DBSpacing.sm)
                .background(Color.dbSurface, in: Capsule())
                .overlay(Capsule().stroke(Color.dbSeparator, lineWidth: 1))

            Button {
                send(to: conversation)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? accent : Color.dbTextTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(DBSpacing.md)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    // MARK: Send + stream

    private func send(to conversation: Conversation) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        HapticEngine.play(.light)

        let userMessage = ChatMessageEntity()
        userMessage.role = .user
        userMessage.text = text
        userMessage.conversation = conversation
        modelContext.insert(userMessage)
        conversation.updatedAt = Date()
        // Auto-title a fresh thread from the first question (handles empty or the
        // "新对话" placeholder so the conversation list never stays generic).
        if conversation.title.isEmpty || conversation.title == "新对话" {
            conversation.title = String(text.prefix(16))
        }
        modelContext.saveLogging()

        let turns = conversation.sortedMessages.map { ChatTurn(role: $0.role, text: $0.text) }
        let request = ChatRequest(turns: turns, context: .preview, kind: mode.chatKind)

        isStreaming = true
        streamingText = ""
        streamingTask?.cancel()
        streamingTask = Task {
            var finalBlocks: [RichBlock] = []
            var route: IntelligenceRoute = .mock
            do {
                for try await chunk in intelligence.chat(request) {
                    try Task.checkCancellation()
                    streamingText += chunk.delta
                    if chunk.isFinal {
                        finalBlocks = chunk.blocks
                        route = chunk.route
                    }
                }
            } catch is CancellationError {
                // View went away mid-stream — abandon without mutating the store.
                return
            } catch {
                finalBlocks = [RichBlock(kind: .text, content: "抱歉，我刚走神了，再问我一次好吗？")]
            }
            // Don't persist onto a context whose view has been dismissed.
            if Task.isCancelled { return }
            let assistant = ChatMessageEntity()
            assistant.role = .assistant
            assistant.text = streamingText.isEmpty ? (finalBlocks.first?.content ?? "") : streamingText
            assistant.blocks = finalBlocks.isEmpty ? [RichBlock(kind: .text, content: assistant.text)] : finalBlocks
            assistant.route = route
            assistant.conversation = conversation
            modelContext.insert(assistant)
            conversation.updatedAt = Date()
            modelContext.saveLogging()
            isStreaming = false
            streamingText = ""
        }
    }

    private func dispatch(_ block: RichBlock) {
        guard block.kind == .suggestion, let action = block.auxiliary else { return }
        switch action {
        case "tutor": router.present(.tutor(problemText: block.content, subject: .general, grade: .g5))
        case "similar": router.openTool(.drill, regular: isRegular)
        case "mistake": router.navigate(.tool(.mistakeNotebook), regular: isRegular)
        default: break
        }
    }
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: ChatMessageEntity
    let accent: Color
    var onBlock: (RichBlock) -> Void

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DBSpacing.xs) {
                ForEach(blocks) { block in
                    blockView(block)
                }
                if let route = message.route, message.role == .assistant {
                    DBRouteBadge(route)
                }
            }
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var blocks: [RichBlock] {
        let b = message.blocks
        return b.isEmpty ? [RichBlock(kind: .text, content: message.text)] : b
    }

    @ViewBuilder
    private func blockView(_ block: RichBlock) -> some View {
        switch block.kind {
        case .suggestion:
            Button { onBlock(block) } label: {
                Label(block.content, systemImage: "sparkles").font(.dbFootnote.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DBSpacing.md).padding(.vertical, DBSpacing.sm - 2)
            .foregroundStyle(accent)
            .background(accent.opacity(0.12), in: Capsule())
        case .math:
            MathText(block.content).padding(DBSpacing.md).bubbleStyle(role: message.role, accent: accent)
        default:
            Text(block.content)
                .font(.dbBody)
                .foregroundStyle(message.role == .user ? Color.dbOnPrimary : Color.dbTextPrimary)
                .padding(DBSpacing.md)
                .bubbleStyle(role: message.role, accent: accent)
        }
    }
}

private struct StreamingBubble: View {
    let text: String
    let accent: Color
    var body: some View {
        HStack {
            (text.isEmpty ? Text("豆包正在思考…") : Text(text))
                .font(.dbBody)
                .foregroundStyle(Color.dbTextPrimary)
                .padding(DBSpacing.md)
                .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
            Spacer(minLength: 40)
        }
    }
}

private extension View {
    @ViewBuilder
    func bubbleStyle(role: ChatRole, accent: Color) -> some View {
        if role == .user {
            self.background(accent, in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        } else {
            self.background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(conversationID: UUID())
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
}
