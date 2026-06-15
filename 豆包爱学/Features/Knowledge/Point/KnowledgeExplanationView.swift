//
//  KnowledgeExplanationView.swift
//  豆包爱学 — Features/Knowledge/Point
//
//  A lightweight, self-contained 知识点讲解 card (RESEARCH F44). Drop it into a
//  home feed, a course detail, a mistake-review sheet, or anywhere a compact
//  "explain this point" surface is useful. It owns its own async lifecycle and
//  handles loading / streaming / error / empty / offline via `ViewState`.
//
//  Unlike `KnowledgePointView` (the full routed detail screen), this requires no
//  SwiftData entity — you pass the point name, subject and grade directly.
//

import SwiftUI

/// Compact, reusable explanation card for a knowledge point.
struct KnowledgeExplanationView: View {
    let knowledgePoint: String
    let subject: Subject
    let grade: GradeLevel
    /// Optional tap handler for an extension question (e.g. open the tutor). When
    /// nil, the chips render but are non-interactive.
    var onExtensionQuestion: ((String) -> Void)?

    @Environment(\.intelligence) private var intelligence
    @Environment(TTSService.self) private var tts

    @State private var state: ViewState<KnowledgeExplanation> = .idle

    init(
        knowledgePoint: String,
        subject: Subject,
        grade: GradeLevel,
        onExtensionQuestion: ((String) -> Void)? = nil
    ) {
        self.knowledgePoint = knowledgePoint
        self.subject = subject
        self.grade = grade
        self.onExtensionQuestion = onExtensionQuestion
    }

    private var tint: Color { DBSubjectColor.color(for: subject) }

    var body: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                header
                Divider().overlay(Color.dbSeparator)
                DBStateContainer(state, retry: { Task { await load() } }) { explanation in
                    loaded(explanation)
                }
                .frame(minHeight: state.value == nil ? 140 : 0)
            }
        }
        .task(id: cacheKey) { await load() }
        .onDisappear { tts.stop() }
    }

    private var cacheKey: String { "\(knowledgePoint)|\(subject.rawValue)|\(grade.rawValue)" }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: DBSpacing.sm) {
            Image(systemName: subject.symbolName)
                .font(.dbCallout)
                .foregroundStyle(Color.dbOnPrimary)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(knowledgePoint).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                Text("\(subject.displayName) · \(grade.displayName)")
                    .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
            if let route = state.value?.route {
                DBRouteBadge(route)
            }
        }
    }

    // MARK: Loaded

    @ViewBuilder
    private func loaded(_ explanation: KnowledgeExplanation) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            ForEach(explanation.sections) { section in
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text(section.heading)
                        .font(.dbSubheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(section.body)
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let math = section.math, !math.isEmpty {
                        MathText(math, font: .dbMonoBody)
                            .padding(.vertical, DBSpacing.xs)
                    }
                }
            }

            if !explanation.extensionQuestions.isEmpty {
                DBFlowLayout(spacing: DBSpacing.xs) {
                    ForEach(Array(explanation.extensionQuestions.enumerated()), id: \.offset) { _, question in
                        if let onExtensionQuestion {
                            Button {
                                onExtensionQuestion(question)
                            } label: {
                                DBChip(question, systemImage: "questionmark.bubble", tint: tint)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("追问：\(question)")
                        } else {
                            DBChip(question, systemImage: "questionmark.bubble", tint: tint)
                        }
                    }
                }
            }
        }
    }

    // MARK: Load

    private func load() async {
        state = .loading
        do {
            let request = ExplainRequest(knowledgePoint: knowledgePoint, subject: subject, grade: grade)
            let explanation = try await intelligence.explainKnowledgePoint(request)
            if explanation.sections.isEmpty {
                state = .empty(message: "暂时没有这个知识点的讲解。")
            } else {
                state = .loaded(explanation)
            }
        } catch let error as IntelligenceError {
            switch error {
            case .unavailable:
                state = .offline(message: "智能服务离线，连网后再看讲解。")
            case .emptyInput:
                state = .empty(message: "还没有选择知识点。")
            case .generationFailed(let reason):
                state = .error(message: reason.isEmpty ? "讲解生成失败。" : reason)
            }
        } catch {
            state = .error(message: "讲解生成失败，请重试。")
        }
    }
}

// MARK: - Preview

#Preview("可复用讲解卡") {
    ScrollView {
        VStack(spacing: DBSpacing.md) {
            KnowledgeExplanationView(
                knowledgePoint: "勾股定理",
                subject: .math,
                grade: .g8,
                onExtensionQuestion: { _ in }
            )
            KnowledgeExplanationView(
                knowledgePoint: "光合作用",
                subject: .biology,
                grade: .g7
            )
        }
        .padding(DBSpacing.screenInset)
    }
    .background(Color.dbBackground)
    .environment(TTSService())
}
