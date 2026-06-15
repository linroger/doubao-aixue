//
//  MistakePaperSheet.swift
//  豆包爱学 — Features/Knowledge/MistakeNotebook
//
//  错题试卷 (组卷): turn a multi-selection of 错题 into a printable practice
//  paper. The sheet shows a clean exam-style layout (题干 + 作答区, answers on a
//  trailing 参考答案 page) and offers share / print affordances. Printing is
//  iOS-only (UIPrintInteractionController); macOS falls back to ShareLink so the
//  generated text can be saved or AirDropped.
//

import SwiftUI

// MARK: - Paper model

/// A pure, Sendable snapshot of the questions chosen for a 错题试卷.
nonisolated struct MistakePaper: Sendable, Identifiable {
    struct Question: Sendable, Identifiable {
        let id: UUID
        let index: Int
        let subject: Subject
        let questionText: String
        let correctAnswer: String
        let errorTypeName: String
        let isMathy: Bool
    }

    let id = UUID()
    let title: String
    let createdAt: Date
    let questions: [Question]

    var subjectsSummary: String {
        let subjects = Array(Set(questions.map(\.subject))).sorted { $0.displayName < $1.displayName }
        return subjects.map(\.displayName).joined(separator: " · ")
    }

    /// Plain-text export used by ShareLink / printing fallback.
    var plainText: String {
        var lines: [String] = []
        lines.append(title)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        lines.append("生成日期：\(formatter.string(from: createdAt))　共 \(questions.count) 题　\(subjectsSummary)")
        lines.append("姓名：____________　　得分：__________")
        lines.append("")
        lines.append("—— 一、答题区 ——")
        for q in questions {
            lines.append("\(q.index). 【\(q.subject.displayName)】\(q.questionText)")
            lines.append("    答：________________________________")
            lines.append("")
        }
        lines.append("—— 二、参考答案 ——")
        for q in questions {
            lines.append("\(q.index). \(q.correctAnswer)　(易错：\(q.errorTypeName))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Builder

enum MistakePaperBuilder {
    static func build(from items: [MistakeItem], title: String) -> MistakePaper {
        let questions = items.enumerated().map { offset, item in
            MistakePaper.Question(
                id: item.id,
                index: offset + 1,
                subject: item.subject,
                questionText: item.questionText,
                correctAnswer: item.correctAnswer.isEmpty ? "见解析" : item.correctAnswer,
                errorTypeName: item.errorType.displayName,
                isMathy: MistakePresentation.isMathy(item.questionText, subject: item.subject)
            )
        }
        return MistakePaper(title: title, createdAt: Date(), questions: questions)
    }
}

// MARK: - Sheet

/// The generated-paper preview with share & print affordances.
struct MistakePaperSheet: View {
    let paper: MistakePaper
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DBSpacing.lg) {
                    masthead
                    answerSection
                    DBSectionHeader("参考答案", systemImage: "key.fill")
                    answerKey
                }
                .padding(DBSpacing.screenInset)
            }
            .background(Color.dbBackground)
            .navigationTitle("错题试卷")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: DBSpacing.md) {
                        #if os(iOS)
                        Button {
                            PaperPrinter.print(paper)
                        } label: {
                            Label("打印", systemImage: "printer.fill")
                        }
                        #endif
                        ShareLink(item: paper.plainText,
                                  preview: SharePreview(paper.title)) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private var masthead: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Text(paper.title)
                    .font(.dbTitle3)
                    .foregroundStyle(Color.dbTextPrimary)
                HStack(spacing: DBSpacing.md) {
                    Label("\(paper.questions.count) 题", systemImage: "list.number")
                    Label(paper.subjectsSummary, systemImage: "books.vertical.fill")
                }
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
                Divider().padding(.vertical, 2)
                HStack {
                    Text("姓名：____________")
                    Spacer()
                    Text("得分：________")
                }
                .font(.dbCallout)
                .foregroundStyle(Color.dbTextSecondary)
            }
        }
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("答题区", systemImage: "pencil.line")
            ForEach(paper.questions) { q in
                DBCard {
                    VStack(alignment: .leading, spacing: DBSpacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: DBSpacing.sm) {
                            Text("\(q.index).")
                                .font(.dbBodyEmph.monospacedDigit())
                                .foregroundStyle(Color.dbPrimary)
                            DBTag(q.subject.displayName, tint: DBSubjectColor.color(for: q.subject))
                            Spacer()
                        }
                        questionBody(q)
                        RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous)
                            .stroke(Color.dbSeparator, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .frame(height: 56)
                            .overlay(alignment: .topLeading) {
                                Text("作答区")
                                    .font(.dbCaption2)
                                    .foregroundStyle(Color.dbTextTertiary)
                                    .padding(6)
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func questionBody(_ q: MistakePaper.Question) -> some View {
        if q.isMathy {
            MathText(q.questionText, font: .dbBody)
                .foregroundStyle(Color.dbTextPrimary)
        } else {
            Text(q.questionText)
                .font(.dbBody)
                .foregroundStyle(Color.dbTextPrimary)
        }
    }

    private var answerKey: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                ForEach(paper.questions) { q in
                    HStack(alignment: .firstTextBaseline, spacing: DBSpacing.sm) {
                        Text("\(q.index).")
                            .font(.dbCallout.monospacedDigit())
                            .foregroundStyle(Color.dbTextSecondary)
                        if q.isMathy {
                            MathText(q.correctAnswer, font: .dbCallout)
                        } else {
                            Text(q.correctAnswer).font(.dbCallout)
                        }
                        Spacer(minLength: DBSpacing.sm)
                        DBTag(q.errorTypeName, tint: .dbTextTertiary)
                    }
                    if q.index != paper.questions.count {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Printing (iOS only)

#if os(iOS)
import UIKit

enum PaperPrinter {
    static func print(_ paper: MistakePaper) {
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = paper.title

        let formatter = UISimpleTextPrintFormatter(text: paper.plainText)
        formatter.font = .systemFont(ofSize: 14)
        formatter.perPageContentInsets = UIEdgeInsets(top: 48, left: 40, bottom: 48, right: 40)

        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printFormatter = formatter
        controller.present(animated: true, completionHandler: nil)
    }
}
#endif

#Preview("错题试卷") {
    let sample = MistakePaper(
        title: "数学·英语 错题试卷",
        createdAt: Date(),
        questions: [
            .init(id: UUID(), index: 1, subject: .math, questionText: "解方程 2x + 3 = 11",
                  correctAnswer: "x = 4", errorTypeName: "方法错误", isMathy: true),
            .init(id: UUID(), index: 2, subject: .english, questionText: "She ___ to school. (go)",
                  correctAnswer: "goes", errorTypeName: "知识点缺失", isMathy: false),
        ]
    )
    return MistakePaperSheet(paper: sample)
}
