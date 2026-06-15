//
//  MistakeNotebookView.swift
//  豆包爱学 — Features/Knowledge/MistakeNotebook
//
//  错题本 (RESEARCH F12/F38/F46): a filterable, groupable list of collected
//  mistakes with a forgetting-curve review queue and 组卷 (build a practice
//  paper) from a multi-selection. Wired to AppSection.mistakes /
//  ToolKind.mistakeNotebook. (Built by integrator — the mistakes agent
//  delivered the support + paper sheet before disconnecting.)
//

import SwiftUI
import SwiftData

struct MistakeNotebookView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \MistakeItem.createdAt, order: .reverse) private var mistakes: [MistakeItem]

    @State private var reviewFilter: ReviewFilter = .all
    @State private var subjectFilter: Subject?
    @State private var selecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var paper: MistakePaper?

    private var isRegular: Bool { sizeClass != .compact }

    private var filtered: [MistakeItem] {
        let now = Date()
        return mistakes.filter { item in
            switch reviewFilter {
            case .all: true
            case .dueToday: item.nextReviewAt <= now
            case .unmastered: item.mastery != .mastered
            }
        }
        .filter { subjectFilter == nil || $0.subject == subjectFilter }
    }

    private var subjectsPresent: [Subject] {
        Array(Set(mistakes.map(\.subject))).sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        Group {
            if mistakes.isEmpty {
                DBStateView(kind: .empty, title: "还没有错题",
                            message: "做题时遇到的错题会自动收录在这里，继续保持！")
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("错题本")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(selecting ? "完成" : "组卷") {
                    withAnimation { selecting.toggle(); selectedIDs.removeAll() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting { paperBar }
        }
        .sheet(item: $paper) { MistakePaperSheet(paper: $0) }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                filterBar
                ForEach(filtered) { item in
                    row(item)
                }
                if filtered.isEmpty {
                    DBStateView(kind: .success, title: "太棒了", message: "这个筛选下没有需要复习的错题")
                        .frame(height: 200)
                }
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DBSpacing.sm) {
                ForEach(ReviewFilter.allCases) { f in
                    Button { reviewFilter = f } label: {
                        DBChip(f.displayName, systemImage: f.symbolName,
                               tint: .dbPrimary, isSelected: reviewFilter == f)
                    }.buttonStyle(.plain)
                }
                Rectangle().fill(Color.dbSeparator).frame(width: 1, height: 22)
                Button { subjectFilter = nil } label: {
                    DBChip("全部学科", tint: .dbSecondary, isSelected: subjectFilter == nil)
                }.buttonStyle(.plain)
                ForEach(subjectsPresent) { s in
                    Button { subjectFilter = (subjectFilter == s ? nil : s) } label: {
                        DBSubjectChip(s, isSelected: subjectFilter == s)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ item: MistakeItem) -> some View {
        Button {
            if selecting {
                toggle(item)
            } else {
                router.navigate(.mistakeDetail(item.id), regular: isRegular)
            }
        } label: {
            DBCard {
                HStack(alignment: .top, spacing: DBSpacing.md) {
                    if selecting {
                        Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .font(.dbTitle3).foregroundStyle(selectedIDs.contains(item.id) ? Color.dbPrimary : Color.dbTextTertiary)
                    }
                    VStack(alignment: .leading, spacing: DBSpacing.sm) {
                        if MistakePresentation.isMathy(item.questionText, subject: item.subject) {
                            MathText(item.questionText, font: .dbBody).lineLimit(2)
                        } else {
                            Text(item.questionText).font(.dbBody).foregroundStyle(Color.dbTextPrimary).lineLimit(2)
                        }
                        HStack(spacing: DBSpacing.sm) {
                            DBSubjectChip(item.subject)
                            DBTag(item.errorType.displayName, tint: MistakePresentation.errorTypeTint(item.errorType))
                            MasteryBadge(mastery: item.mastery)
                            Spacer()
                            Text(MistakePresentation.dueDescription(for: item.nextReviewAt))
                                .font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var paperBar: some View {
        HStack {
            Text("已选 \(selectedIDs.count) 题").font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
            Spacer()
            Button("生成练习卷") { buildPaper() }
                .buttonStyle(.db(.primary))
                .disabled(selectedIDs.isEmpty)
        }
        .padding(DBSpacing.md)
        .background(.bar)
    }

    private func toggle(_ item: MistakeItem) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
    }

    private func buildPaper() {
        let chosen = mistakes.filter { selectedIDs.contains($0.id) }
        let questions = chosen.enumerated().map { i, item in
            MistakePaper.Question(
                id: item.id, index: i + 1, subject: item.subject,
                questionText: item.questionText, correctAnswer: item.correctAnswer,
                errorTypeName: item.errorType.displayName,
                isMathy: MistakePresentation.isMathy(item.questionText, subject: item.subject))
        }
        paper = MistakePaper(title: "错题练习卷", createdAt: Date(), questions: questions)
        HapticEngine.play(.success)
    }
}

#Preview {
    NavigationStack { MistakeNotebookView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
}
