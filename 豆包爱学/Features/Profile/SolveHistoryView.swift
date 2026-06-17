//
//  SolveHistoryView.swift
//  豆包爱学 — Features/Profile
//
//  历史记录 — every 拍题 / 答疑 solve the learner has done, newest first. Each
//  ProblemRecord shows its subject, the recognized question, the final answer,
//  the AI route badge, and when it was solved. Reachable from 个人中心 → 历史记录,
//  giving that row a real, distinct destination (it used to open 错题本).
//

import SwiftUI
import SwiftData

struct SolveHistoryView: View {
    @Query(sort: \ProblemRecord.createdAt, order: .reverse) private var problems: [ProblemRecord]

    var body: some View {
        Group {
            if problems.isEmpty {
                DBStateView(kind: .empty, title: "还没有解题记录",
                            message: "拍一道题或问豆包一个问题，解题记录就会出现在这里。")
            } else {
                ScrollView {
                    LazyVStack(spacing: DBSpacing.md) {
                        ForEach(problems) { record in
                            row(record)
                        }
                    }
                    .padding(DBSpacing.screenInset)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("历史记录")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func row(_ record: ProblemRecord) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.sm) {
                    DBSubjectChip(record.subject)
                    DBRouteBadge(record.route)
                    if record.savedToMistakes {
                        DBTag("已收错题", tint: .dbWarning)
                    }
                    Spacer(minLength: 0)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
                }

                let question = record.recognizedText.isEmpty ? "（图片题目）" : record.recognizedText
                if record.subject.isSTEM {
                    MathText(question, font: .dbBody).lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(question).font(.dbBody).foregroundStyle(Color.dbTextPrimary)
                        .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                }

                if !record.finalAnswer.isEmpty {
                    Label(record.finalAnswer, systemImage: "checkmark.seal.fill")
                        .font(.dbCallout.weight(.medium))
                        .foregroundStyle(Color.dbSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview("历史记录") {
    NavigationStack { SolveHistoryView() }
        .modelContainer(PreviewSampleData.container)
}
