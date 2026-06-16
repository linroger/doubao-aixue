//
//  WorkbookHistoryView.swift
//  豆包爱学 — Features/Workbook
//
//  批改历史: every 作业批改 is persisted (photo + structured result + metadata) as a
//  `WorkbookGradeRecord`. This screen lists them newest-first; tapping re-renders the
//  exact `GradedWorkbook` via the shared `WorkbookResultContent`, so a past grading
//  looks identical to a fresh one — fully offline, no re-grading needed.
//

import SwiftUI
import SwiftData

struct WorkbookHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkbookGradeRecord.createdAt, order: .reverse) private var records: [WorkbookGradeRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                DBStateView(kind: .empty, title: "还没有批改记录",
                            message: "用「作业批改」拍一页作业，结果会自动保存在这里。")
            } else {
                ScrollView {
                    LazyVStack(spacing: DBSpacing.md) {
                        ForEach(records) { record in
                            NavigationLink {
                                WorkbookHistoryDetailView(record: record)
                            } label: {
                                row(record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DBSpacing.screenInset)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("批改历史")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func row(_ record: WorkbookGradeRecord) -> some View {
        DBCard {
            HStack(spacing: DBSpacing.md) {
                thumbnail(record)
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text(record.title)
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                        .lineLimit(1)
                    HStack(spacing: DBSpacing.sm) {
                        DBSubjectChip(record.subject)
                        DBRouteBadge(record.route)
                    }
                    HStack(spacing: DBSpacing.sm) {
                        Label("\(record.correctCount)/\(record.totalCount) 对",
                              systemImage: "checkmark.circle.fill")
                            .font(.dbCaption.weight(.medium).monospacedDigit())
                            .foregroundStyle(Color.dbSuccess)
                        if record.wrongCount > 0 {
                            Label("\(record.wrongCount) 错", systemImage: "xmark.circle.fill")
                                .font(.dbCaption.weight(.medium).monospacedDigit())
                                .foregroundStyle(Color.dbError)
                        }
                        Spacer(minLength: 0)
                        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
                    }
                }
                Image(systemName: "chevron.right").font(.dbFootnote).foregroundStyle(Color.dbTextTertiary)
            }
        }
        .contextMenu {
            Button(role: .destructive) { delete(record) } label: {
                Label("删除记录", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ record: WorkbookGradeRecord) -> some View {
        if let data = record.imageData, let image = Image.fromWorkbookData(data) {
            image.resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                .fill(Color.dbPrimarySoft)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "doc.text.image")
                        .font(.dbTitle3).foregroundStyle(Color.dbPrimary)
                }
        }
    }

    private func delete(_ record: WorkbookGradeRecord) {
        modelContext.delete(record)
        modelContext.saveLogging()
        HapticEngine.play(.light)
    }
}

// MARK: - Detail (re-render from persisted result)

struct WorkbookHistoryDetailView: View {
    let record: WorkbookGradeRecord

    var body: some View {
        ScrollView {
            Group {
                if let workbook = record.result {
                    WorkbookResultContent(workbook: workbook, imageData: record.imageData)
                } else {
                    DBStateView(kind: .error, title: "无法打开", message: "这条批改记录已损坏或为旧版本格式。")
                        .frame(minHeight: 300)
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("批改详情")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview("批改历史") {
    NavigationStack { WorkbookHistoryView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
