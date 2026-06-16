//
//  ProfileEditSheet.swift
//  豆包爱学 — Features/Profile
//
//  Editable grade / 学科 / 教材版本 + nickname. Re-personalizes the learner
//  profile post-onboarding (RESEARCH F54: "the place to change grade/subject").
//  Edits are staged locally and committed to SwiftData on 保存.
//

import SwiftUI
import SwiftData

struct ProfileEditSheet: View {
    @Bindable var profile: LearnerProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Staged edits (committed on 保存).
    @State private var nickname: String = ""
    @State private var grade: GradeLevel = .g5
    @State private var selectedSubjects: Set<Subject> = []
    @State private var editions: [Subject: TextbookEdition] = [:]
    @State private var didLoad = false

    /// Subjects offered for selection (omit the catch-all 拓展类 generals).
    private let selectableSubjects: [Subject] = [
        .math, .chinese, .english, .physics, .chemistry,
        .biology, .history, .geography, .politics, .science,
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DBSpacing.lg) {
                    nicknameCard
                    gradeCard
                    subjectsCard
                    if !selectedSubjects.isEmpty {
                        editionsCard
                    }
                }
                .padding(DBSpacing.screenInset)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color.dbBackground)
            .navigationTitle("编辑资料")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedNickname.isEmpty)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Nickname

    private var nicknameCard: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("昵称", systemImage: "person.fill")
            DBCard(fill: .dbSurface, elevation: .low) {
                HStack(spacing: DBSpacing.md) {
                    DBAvatar(name: trimmedNickname.isEmpty ? "小学员" : trimmedNickname, size: 48, gradeBadge: grade.displayName)
                    TextField("起个昵称吧", text: $nickname)
                        .textFieldStyle(.plain)
                        .font(.dbBody)
                        #if os(iOS)
                        .submitLabel(.done)
                        #endif
                }
            }
        }
    }

    // MARK: Grade

    private var gradeCard: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("年级", subtitle: "切换年级会重新匹配学习内容", systemImage: "graduationcap.fill")
            DBCard(fill: .dbSurface, elevation: .low) {
                VStack(alignment: .leading, spacing: DBSpacing.md) {
                    ForEach(ProfileGradeGroup.allGroups, id: \.stage) { group in
                        VStack(alignment: .leading, spacing: DBSpacing.xs) {
                            Text(group.stage.displayName)
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextSecondary)
                            DBFlowLayout(spacing: DBSpacing.xs) {
                                ForEach(group.grades) { level in
                                    Button {
                                        grade = level
                                        HapticEngine.play(.selection)
                                    } label: {
                                        DBChip(level.displayName, isSelected: grade == level)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Subjects

    private var subjectsCard: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("学科", subtitle: "选择你正在学习的科目", systemImage: "books.vertical.fill")
            DBCard(fill: .dbSurface, elevation: .low) {
                DBFlowLayout(spacing: DBSpacing.xs) {
                    ForEach(selectableSubjects) { subject in
                        Button {
                            toggleSubject(subject)
                            HapticEngine.play(.selection)
                        } label: {
                            DBSubjectChip(subject, isSelected: selectedSubjects.contains(subject))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Editions

    private var editionsCard: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("教材版本", subtitle: "内容会对齐所选版本", systemImage: "text.book.closed.fill")
            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                VStack(spacing: 0) {
                    ForEach(Array(orderedSelectedSubjects.enumerated()), id: \.element) { index, subject in
                        HStack(spacing: DBSpacing.md) {
                            Image(systemName: subject.symbolName)
                                .font(.dbBody)
                                .foregroundStyle(DBSubjectColor.color(for: subject))
                                .frame(width: 30)
                            Text(subject.displayName)
                                .font(.dbBody)
                                .foregroundStyle(Color.dbTextPrimary)
                            Spacer(minLength: DBSpacing.sm)
                            Picker("", selection: editionBinding(for: subject)) {
                                ForEach(TextbookEdition.allCases) { edition in
                                    Text(edition.displayName).tag(edition)
                                }
                            }
                            .labelsHidden()
                            .tint(Color.dbPrimary)
                        }
                        .padding(.vertical, DBSpacing.xs)
                        if index < orderedSelectedSubjects.count - 1 {
                            ProfileRowDivider()
                        }
                    }
                }
            }
        }
    }

    // MARK: Logic

    /// Selected subjects in the stable display order of `selectableSubjects`.
    private var orderedSelectedSubjects: [Subject] {
        selectableSubjects.filter { selectedSubjects.contains($0) }
    }

    private func editionBinding(for subject: Subject) -> Binding<TextbookEdition> {
        Binding(
            get: { editions[subject] ?? .unspecified },
            set: { editions[subject] = $0 }
        )
    }

    private func toggleSubject(_ subject: Subject) {
        if selectedSubjects.contains(subject) {
            selectedSubjects.remove(subject)
            editions[subject] = nil
        } else {
            selectedSubjects.insert(subject)
            if editions[subject] == nil { editions[subject] = .unspecified }
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        nickname = profile.nickname
        grade = profile.grade
        selectedSubjects = Set(profile.subjects)
        editions = profile.editions
        didLoad = true
    }

    private func save() {
        let name = trimmedNickname
        profile.nickname = name.isEmpty ? "小学员" : name
        profile.grade = grade
        // Preserve the user's chosen order via the selectable list.
        profile.subjects = selectableSubjects.filter { selectedSubjects.contains($0) }
        // Keep only editions for selected subjects.
        profile.editions = editions.filter { selectedSubjects.contains($0.key) }
        profile.onboardingComplete = true
        profile.lastActiveAt = Date()
        modelContext.saveLogging()
        HapticEngine.play(.success)
        dismiss()
    }
}

/// Grades grouped by stage for a tidy two-tier grade picker.
private struct ProfileGradeGroup {
    let stage: GradeStage
    let grades: [GradeLevel]

    static let allGroups: [ProfileGradeGroup] = [
        ProfileGradeGroup(stage: .primary, grades: [.g1, .g2, .g3, .g4, .g5, .g6]),
        ProfileGradeGroup(stage: .juniorHigh, grades: [.g7, .g8, .g9]),
        ProfileGradeGroup(stage: .seniorHigh, grades: [.g10, .g11, .g12]),
    ]
}

#Preview("编辑资料") {
    ProfileEditSheet(profile: ProfilePreviewData.sampleProfile)
        .modelContainer(ProfilePreviewData.container)
}
