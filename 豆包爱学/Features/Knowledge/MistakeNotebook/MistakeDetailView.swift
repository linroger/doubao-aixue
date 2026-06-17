//
//  MistakeDetailView.swift
//  豆包爱学 — Features/Knowledge/MistakeNotebook
//
//  错题详情 (RESEARCH F38): original question, 你的答案 vs 正确答案, 错因, 解题步骤,
//  knowledge points, and a forgetting-curve review (again/hard/good/easy) that
//  reschedules and updates mastery. Wired to Route.mistakeDetail(UUID).
//

import SwiftUI
import SwiftData

struct MistakeDetailView: View {
    let mistakeID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var mistakes: [MistakeItem]
    @Query private var knowledgePoints: [KnowledgePointEntity]
    @State private var justReviewed = false
    @State private var savedToBank = false

    init(mistakeID: UUID) { self.mistakeID = mistakeID }

    private var item: MistakeItem? { mistakes.first { $0.id == mistakeID } }
    private var isRegular: Bool { sizeClass != .compact }

    /// Resolve a knowledge-point id to its display name so chips read as concepts
    /// ("二次函数的图象") rather than raw ids ("kp-quadratic-graph").
    private func knowledgePointName(_ id: String) -> String {
        knowledgePoints.first { $0.id == id }?.name ?? id
    }

    var body: some View {
        Group {
            if let item {
                detail(item)
            } else {
                DBStateView(kind: .empty, title: "错题不存在", message: "它可能已被移除")
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("错题详情")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func detail(_ item: MistakeItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                // Question
                DBCard {
                    VStack(alignment: .leading, spacing: DBSpacing.sm) {
                        HStack { DBSubjectChip(item.subject); Spacer(); MasteryBadge(mastery: item.mastery) }
                        if MistakePresentation.isMathy(item.questionText, subject: item.subject) {
                            MathText(item.questionText, font: .dbTitle3)
                        } else {
                            Text(item.questionText).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                        }
                    }
                }

                // Answers diff
                HStack(spacing: DBSpacing.md) {
                    answerCard("你的答案", value: item.studentAnswer, tint: .dbError, symbol: "xmark.circle.fill")
                    answerCard("正确答案", value: item.correctAnswer, tint: .dbSuccess, symbol: "checkmark.circle.fill")
                }

                // Error cause
                DBCard(fill: .dbErrorSoft, elevation: .none) {
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Label(item.errorType.displayName, systemImage: "lightbulb.fill")
                            .font(.dbHeadline).foregroundStyle(MistakePresentation.errorTypeTint(item.errorType))
                        if !item.errorReason.isEmpty {
                            Text(item.errorReason).font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                        }
                    }
                }

                // Steps
                if !item.steps.isEmpty {
                    DBSectionHeader("解题步骤", systemImage: "list.number")
                    ForEach(item.steps) { step in
                        DBCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("第\(step.index)步 · \(step.title)").font(.dbBodyEmph)
                                Text(step.detail).font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                                if let math = step.math { MathText(math, font: .dbBody) }
                            }
                        }
                    }
                }

                // Knowledge points
                if !item.knowledgePointIDs.isEmpty {
                    DBSectionHeader("相关知识点", systemImage: "point.3.connected.trianglepath.dotted")
                    DBFlowLayout(spacing: 8) {
                        ForEach(item.knowledgePointIDs, id: \.self) { kpID in
                            Button { router.navigate(.knowledgePoint(kpID), regular: isRegular) } label: {
                                DBChip(knowledgePointName(kpID), systemImage: "lightbulb", tint: .dbSecondary)
                            }.buttonStyle(.plain)
                        }
                    }
                }

                // Review actions
                reviewSection(item)

                // Secondary actions
                HStack(spacing: DBSpacing.md) {
                    Button { router.present(.tutor(problemText: item.questionText, subject: item.subject, grade: .g5)) } label: {
                        Label("重新讲解", systemImage: "person.wave.2.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.db(.secondary))
                    Button { router.openDrill(knowledgePointID: item.knowledgePointIDs.first, regular: isRegular) } label: {
                        Label("举一反三", systemImage: "square.grid.3x3.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.db(.ghost))
                }

                // Collect this mistake into the 题库 so it can seed 智能出题 too.
                Button { saveToBank(item) } label: {
                    Label(savedToBank ? "已加入题库" : "加入题库",
                          systemImage: savedToBank ? "checkmark.circle.fill" : "tray.full.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.db(.ghost))
                .disabled(savedToBank)
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private func saveToBank(_ item: MistakeItem) {
        guard !savedToBank else { return }
        let names = item.knowledgePointIDs.map { knowledgePointName($0) }
        let q = BankedQuestion.make(from: item, knowledgePointNames: names)
        modelContext.insert(q)
        if modelContext.saveLogging() {
            savedToBank = true
            HapticEngine.play(.success)
        }
    }

    private func answerCard(_ title: String, value: String, tint: Color, symbol: String) -> some View {
        DBCard(fill: tint.opacity(0.1), elevation: .none) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol).font(.dbCaption.weight(.semibold)).foregroundStyle(tint)
                Text(value.isEmpty ? "—" : value).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reviewSection(_ item: MistakeItem) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack {
                    Label("复习一下", systemImage: "arrow.triangle.2.circlepath").font(.dbHeadline)
                    Spacer()
                    Text(MistakePresentation.dueDescription(for: item.nextReviewAt))
                        .font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                }
                if justReviewed {
                    Label("已记录，下次复习时间已更新", systemImage: "checkmark.seal.fill")
                        .font(.dbCallout).foregroundStyle(Color.dbSuccess)
                } else {
                    Text("根据遗忘曲线，诚实地评估你现在的掌握程度：").font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                    HStack(spacing: DBSpacing.sm) {
                        ForEach(ReviewGrade.allCases, id: \.rawValue) { grade in
                            Button { review(item, grade) } label: {
                                Text(grade.displayName).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.db(grade == .again ? .ghost : .secondary))
                        }
                    }
                }
            }
        }
    }

    private func review(_ item: MistakeItem, _ grade: ReviewGrade) {
        item.reviewCount += 1
        item.lastReviewedAt = Date()
        let days: Int
        switch grade {
        case .again: item.mastery = .weak; days = 1
        case .hard:  item.mastery = .developing; days = 2
        case .good:  item.mastery = item.reviewCount >= 3 ? .mastered : .developing; days = 4
        case .easy:  item.mastery = .mastered; days = 7
        }
        item.nextReviewAt = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        modelContext.saveLogging()
        HapticEngine.play(.success)
        withAnimation { justReviewed = true }
    }
}

#Preview {
    NavigationStack { MistakeDetailView(mistakeID: UUID()) }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
}
