//
//  OnboardingModel.swift
//  豆包爱学 — Features/Onboarding
//
//  Draft state + persistence for the first-run wizard (RESEARCH F52/F53).
//  Collects 学段 → 年级 → 学科 → 教材版本 and writes the personalization
//  baseline onto a (new or existing) LearnerProfile.
//

import SwiftUI
import SwiftData

// MARK: - Steps

/// Ordered wizard steps. Pure value type so it stays trivially testable and
/// works with the progress-dot indicator. `nonisolated` per the foundation rules.
nonisolated enum OnboardingStep: Int, CaseIterable, Identifiable, Comparable {
    case welcome
    case stage
    case grade
    case subjects
    case edition
    case privacy

    var id: Int { rawValue }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Steps shown as progress dots (the welcome splash is excluded so the dots
    /// represent the actual data-collection journey).
    static var trackedSteps: [OnboardingStep] { [.stage, .grade, .subjects, .edition, .privacy] }

    /// Position (1-based) within the tracked steps, or nil for the welcome splash.
    var trackedIndex: Int? {
        Self.trackedSteps.firstIndex(of: self).map { $0 + 1 }
    }

    var mascotMood: DBMascotMood {
        switch self {
        case .welcome: .cheering
        case .stage, .grade: .happy
        case .subjects: .curious
        case .edition: .thinking
        case .privacy: .happy
        }
    }
}

// MARK: - Model

/// Drives the onboarding wizard: holds the in-progress selections and commits
/// them to a `LearnerProfile` in SwiftData on finish.
@Observable
@MainActor
final class OnboardingModel {
    // Draft selections (sensible defaults so the user can always advance).
    var step: OnboardingStep = .welcome
    var stage: GradeStage = .primary
    var grade: GradeLevel = .g3
    var selectedSubjects: Set<Subject> = []
    var editions: [Subject: TextbookEdition] = [:]

    /// True while the finish write is in flight (drives the saving spinner).
    var isSaving = false
    /// Set when persistence fails so the UI can show a retry affordance.
    var saveErrorMessage: String?

    /// Subjects offered for selection — K12 academic subjects (excludes the
    /// internal `.general` bucket which is never a user preference).
    static let selectableSubjects: [Subject] = [
        .chinese, .math, .english,
        .physics, .chemistry, .biology,
        .history, .geography, .politics, .science
    ]

    // MARK: Stage → grade coupling

    /// Grade levels that belong to the currently selected stage.
    var gradesForStage: [GradeLevel] {
        GradeLevel.allCases.filter { $0.stage == stage }
    }

    /// Keep `grade` valid whenever the stage changes; snaps to the first grade
    /// of the new stage (or college's sentinel) so 年级 is never inconsistent.
    func syncGradeToStage() {
        if grade.stage != stage {
            grade = gradesForStage.first ?? .g5
        }
    }

    /// College has no concrete K12 grade chips, so the 年级 step is skipped.
    var skipsGradeStep: Bool { stage == .college }

    // MARK: Subject defaults

    /// Recommended subjects pre-checked for a stage, so the user starts with a
    /// sensible, encouraging baseline rather than an empty screen.
    func recommendedSubjects(for stage: GradeStage) -> Set<Subject> {
        switch stage {
        case .primary:    [.chinese, .math, .english]
        case .juniorHigh: [.chinese, .math, .english, .physics]
        case .seniorHigh: [.chinese, .math, .english, .physics, .chemistry]
        case .college:    [.english, .math]
        }
    }

    /// Apply recommended subjects only if the user has not chosen any yet.
    func seedRecommendedSubjectsIfEmpty() {
        if selectedSubjects.isEmpty {
            selectedSubjects = recommendedSubjects(for: stage)
        }
    }

    func toggleSubject(_ subject: Subject) {
        if selectedSubjects.contains(subject) {
            selectedSubjects.remove(subject)
            editions[subject] = nil
        } else {
            selectedSubjects.insert(subject)
        }
    }

    // MARK: Editions

    /// Editions a learner can pick per subject. English uses 外研版; the rest use
    /// the common mainland mainstream editions.
    func editionOptions(for subject: Subject) -> [TextbookEdition] {
        switch subject {
        case .english:
            [.renjiao, .waiyan, .beishida, .unspecified]
        default:
            [.renjiao, .beishida, .sujiao, .huadong, .rujiao, .unspecified]
        }
    }

    /// Subjects offered in the (optional) edition step, in a stable display order.
    var subjectsForEditionStep: [Subject] {
        Self.selectableSubjects.filter { selectedSubjects.contains($0) }
    }

    // MARK: Step navigation

    /// The next step, honoring the college grade-skip. Returns nil when finished.
    func nextStep(after current: OnboardingStep) -> OnboardingStep? {
        var candidate = OnboardingStep(rawValue: current.rawValue + 1)
        if candidate == .grade, skipsGradeStep {
            candidate = OnboardingStep(rawValue: OnboardingStep.grade.rawValue + 1)
        }
        return candidate
    }

    /// The previous step, honoring the college grade-skip. Returns nil at the start.
    func previousStep(before current: OnboardingStep) -> OnboardingStep? {
        guard current.rawValue > 0 else { return nil }
        var candidate = OnboardingStep(rawValue: current.rawValue - 1)
        if candidate == .grade, skipsGradeStep {
            candidate = OnboardingStep(rawValue: OnboardingStep.grade.rawValue - 1)
        }
        return candidate
    }

    /// Whether the user may advance from the current step. Subjects must be
    /// non-empty; everything else always has a valid default.
    var canAdvanceFromCurrentStep: Bool {
        switch step {
        case .subjects: !selectedSubjects.isEmpty
        default: true
        }
    }

    var isOnLastStep: Bool { nextStep(after: step) == nil }

    // MARK: Persistence

    /// Create or update the single `LearnerProfile` with the collected baseline
    /// and mark onboarding complete. RootView's `@Query` flips to the main shell
    /// automatically once `onboardingComplete` becomes true.
    func finish(context: ModelContext) {
        isSaving = true
        saveErrorMessage = nil

        let profile: LearnerProfile
        if let existing = try? context.fetch(FetchDescriptor<LearnerProfile>()).first {
            profile = existing
        } else {
            profile = LearnerProfile()
            context.insert(profile)
        }

        // The foundation profile derives `stage` from `grade` and has no concrete
        // college grade, so a college learner maps to the highest K12 grade (g12)
        // while still recording the chosen subjects/editions.
        profile.grade = (stage == .college) ? .g12 : grade
        profile.subjects = orderedSelectedSubjects
        profile.editions = editions.filter { selectedSubjects.contains($0.key) }
        profile.preferredRoute = .onDevice
        profile.lastActiveAt = Date()
        profile.onboardingComplete = true

        do {
            try context.save()
            HapticEngine.play(.success)
            isSaving = false
        } catch {
            saveErrorMessage = "保存失败，请重试。你的选择已为你保留。"
            HapticEngine.play(.error)
            isSaving = false
        }
    }

    /// Selected subjects in the canonical display order (stable, reproducible).
    private var orderedSelectedSubjects: [Subject] {
        Self.selectableSubjects.filter { selectedSubjects.contains($0) }
    }
}
