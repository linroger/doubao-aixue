//
//  OnboardingView.swift
//  豆包爱学 — Features/Onboarding
//
//  First-run onboarding wizard (RESEARCH F52/F53). A delightful, mascot-led
//  stepper that collects 学段 → 年级 → 学科 → 教材版本, shows a "私密 · 端侧"
//  trust message, and writes the personalization baseline to a LearnerProfile.
//
//  Wiring: the integrator shows `OnboardingView()` from RootView when no
//  onboarded profile exists. On finish we set `onboardingComplete = true` and
//  save; RootView's `@Query` then flips to the main shell automatically — this
//  view does not dismiss itself or build its own NavigationStack.
//

import SwiftUI
import SwiftData
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @State private var model = OnboardingModel()
    /// True once the user has either signed in with Apple or tapped "稍后".
    /// Cosmetic only — never blocks finishing onboarding.
    @State private var hasResolvedSignIn = false

    init() {}

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                header

                stepContent
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(model.step)

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: model.step)
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    // MARK: Backdrop

    private var backdrop: some View {
        ZStack {
            Color.dbBackground
            // Soft warm glow behind the wizard for a friendly first impression.
            Color.dbHeroGradient
                .opacity(colorScheme == .dark ? 0.12 : 0.16)
                .blur(radius: 80)
                .frame(height: 340)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    // MARK: Header (mascot + progress dots)

    private var header: some View {
        VStack(spacing: DBSpacing.md) {
            DBMascot(mood: model.step.mascotMood, size: model.step == .welcome ? 132 : 84)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: model.step)
                .padding(.top, DBSpacing.xxl)

            if let index = model.step.trackedIndex {
                OnboardingProgressDots(
                    total: OnboardingStep.trackedSteps.count,
                    current: index
                )
                .accessibilityLabel("第 \(index) 步，共 \(OnboardingStep.trackedSteps.count) 步")
            } else {
                // Reserve space so the layout doesn't jump from the welcome step.
                Color.clear.frame(height: 12)
            }
        }
        .padding(.horizontal, DBSpacing.screenInset)
    }

    // MARK: Step content

    @ViewBuilder private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.xl) {
                switch model.step {
                case .welcome:  WelcomeStep()
                case .stage:    StageStep(model: model)
                case .grade:    GradeStep(model: model)
                case .subjects: SubjectsStep(model: model)
                case .edition:  EditionStep(model: model)
                case .privacy:  PrivacyStep(hasResolvedSignIn: $hasResolvedSignIn)
                }
            }
            .padding(.horizontal, DBSpacing.screenInset)
            .padding(.vertical, DBSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Footer (navigation + save state)

    private var footer: some View {
        VStack(spacing: DBSpacing.sm) {
            if let message = model.saveErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbError)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            HStack(spacing: DBSpacing.md) {
                if model.previousStep(before: model.step) != nil {
                    Button {
                        goBack()
                    } label: {
                        Label("上一步", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.db(.ghost))
                    .disabled(model.isSaving)
                }

                Button {
                    advance()
                } label: {
                    Group {
                        if model.isSaving {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Text(primaryButtonTitle)
                        }
                    }
                }
                .buttonStyle(.db(.primary, fullWidth: true))
                .disabled(!model.canAdvanceFromCurrentStep || model.isSaving)
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, DBSpacing.screenInset)
        .padding(.bottom, DBSpacing.xl)
        .padding(.top, DBSpacing.sm)
        .background(alignment: .top) {
            // Subtle hairline so the footer reads as a pinned action bar.
            Rectangle().fill(Color.dbSeparator.opacity(0.6)).frame(height: 0.5)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .animation(.spring(duration: 0.3), value: model.saveErrorMessage)
    }

    private var primaryButtonTitle: String {
        switch model.step {
        case .welcome:  "开始啦"
        case .privacy:  "进入豆包爱学"
        default:        "下一步"
        }
    }

    // MARK: Actions

    private func advance() {
        HapticEngine.play(.light)
        if model.isOnLastStep {
            model.finish(context: context)
            return
        }
        // Seed sensible subject defaults the first time we reach the subject step.
        if model.step == .grade || (model.step == .stage && model.skipsGradeStep) {
            model.seedRecommendedSubjectsIfEmpty()
        }
        if let next = model.nextStep(after: model.step) {
            model.step = next
        }
    }

    private func goBack() {
        HapticEngine.play(.selection)
        model.saveErrorMessage = nil
        if let prev = model.previousStep(before: model.step) {
            model.step = prev
        }
    }
}

// MARK: - Progress dots

private struct OnboardingProgressDots: View {
    let total: Int
    let current: Int   // 1-based

    var body: some View {
        HStack(spacing: DBSpacing.sm) {
            ForEach(1...total, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == current ? AnyShapeStyle(Color.dbHeroGradient)
                                            : AnyShapeStyle(Color.dbSeparator))
                    .frame(width: index == current ? 26 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
    }
}

// MARK: - Step: Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: DBSpacing.lg) {
            VStack(spacing: DBSpacing.sm) {
                Text("欢迎来到豆包爱学")
                    .font(.dbLargeTitle)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("你的 AI 学习搭子，端侧私密、随时陪练。\n先花十几秒，让豆包更懂你～")
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: DBSpacing.sm) {
                WelcomeHighlight(icon: "lock.iphone", tint: .dbSecondary,
                                 title: "端侧私密", detail: "作业不离开设备，离线也能用")
                WelcomeHighlight(icon: "wand.and.stars", tint: .dbPrimary,
                                 title: "一拍即解", detail: "拍照搜题、批改、讲解一步到位")
                WelcomeHighlight(icon: "heart.fill", tint: .dbAccent,
                                 title: "温柔陪练", detail: "像大姐姐一样，一步步带你学会")
            }
        }
    }
}

private struct WelcomeHighlight: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        DBCard(padding: DBSpacing.md) {
            HStack(spacing: DBSpacing.md) {
                Image(systemName: icon)
                    .font(.dbTitle3)
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                    Text(detail).font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step: 学段

private struct StageStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            StepTitle(title: "你在哪个学段？", subtitle: "我们会按学段为你匹配合适的内容")

            VStack(spacing: DBSpacing.md) {
                ForEach(GradeStage.allCases) { stage in
                    OnboardingBigChoice(
                        title: stage.displayName,
                        subtitle: stageSubtitle(stage),
                        systemImage: stage.symbolName,
                        tint: .dbPrimary,
                        isSelected: model.stage == stage
                    ) {
                        guard model.stage != stage else { return }
                        HapticEngine.play(.selection)
                        model.stage = stage
                        model.syncGradeToStage()
                    }
                }
            }
        }
    }

    private func stageSubtitle(_ stage: GradeStage) -> String {
        switch stage {
        case .primary: "一年级 ~ 六年级"
        case .juniorHigh: "初一 ~ 初三"
        case .seniorHigh: "高一 ~ 高三"
        case .college: "大学 / 成人学习"
        }
    }
}

// MARK: - Step: 年级

private struct GradeStep: View {
    @Bindable var model: OnboardingModel

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: DBSpacing.md)]

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            StepTitle(title: "你读\(model.stage.displayName)几年级？",
                      subtitle: "选一个就好，之后可以在「我的」里随时修改")

            LazyVGrid(columns: columns, spacing: DBSpacing.md) {
                ForEach(model.gradesForStage) { grade in
                    OnboardingGradePill(
                        title: grade.displayName,
                        isSelected: model.grade == grade
                    ) {
                        guard model.grade != grade else { return }
                        HapticEngine.play(.selection)
                        model.grade = grade
                    }
                }
            }
        }
    }
}

// MARK: - Step: 学科

private struct SubjectsStep: View {
    @Bindable var model: OnboardingModel

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: DBSpacing.md)]

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            StepTitle(title: "你想重点学哪些学科？",
                      subtitle: "可以多选，已为你推荐了常学的几科")

            LazyVGrid(columns: columns, spacing: DBSpacing.md) {
                ForEach(OnboardingModel.selectableSubjects) { subject in
                    OnboardingSubjectTile(
                        subject: subject,
                        isSelected: model.selectedSubjects.contains(subject)
                    ) {
                        HapticEngine.play(.selection)
                        model.toggleSubject(subject)
                    }
                }
            }

            if model.selectedSubjects.isEmpty {
                Label("至少选择一个学科～", systemImage: "hand.point.up.left.fill")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
            } else {
                Text("已选 \(model.selectedSubjects.count) 科")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbPrimaryDeep)
            }
        }
    }
}

// MARK: - Step: 教材版本 (optional)

private struct EditionStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            StepTitle(title: "用的是哪个版本的教材？",
                      subtitle: "选填 · 选好后内容会更贴合你的课本，不确定可跳过")

            ForEach(model.subjectsForEditionStep) { subject in
                EditionSubjectRow(model: model, subject: subject)
            }

            DBCard(fill: .dbSecondarySoft, elevation: .none) {
                Label {
                    Text("不确定也没关系，先用「通用版」，以后随时能改。")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                } icon: {
                    Image(systemName: "info.circle.fill").foregroundStyle(Color.dbSecondary)
                }
            }
        }
    }
}

private struct EditionSubjectRow: View {
    @Bindable var model: OnboardingModel
    let subject: Subject

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            HStack(spacing: DBSpacing.sm) {
                Image(systemName: subject.symbolName)
                    .font(.dbSubheadline)
                    .foregroundStyle(DBSubjectColor.color(for: subject))
                Text(subject.displayName).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
            }

            DBFlowLayout(spacing: DBSpacing.sm) {
                ForEach(model.editionOptions(for: subject)) { edition in
                    let isSelected = selectedEdition == edition
                    Button {
                        HapticEngine.play(.selection)
                        model.editions[subject] = isSelected ? nil : edition
                    } label: {
                        DBChip(edition.displayName,
                               tint: DBSubjectColor.color(for: subject),
                               isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, DBSpacing.xs)
    }

    private var selectedEdition: TextbookEdition? { model.editions[subject] }
}

// MARK: - Step: Privacy + optional Sign in with Apple

private struct PrivacyStep: View {
    @Binding var hasResolvedSignIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            StepTitle(title: "你的学习，始终私密",
                      subtitle: "全部为你准备好了，最后看一眼安心承诺")

            VStack(spacing: DBSpacing.sm) {
                PrivacyPoint(icon: "lock.iphone", tint: .dbSecondary,
                             title: "端侧优先", detail: "作业、错题、答案默认只存在这台设备上")
                PrivacyPoint(icon: "wifi.slash", tint: .dbPrimary,
                             title: "离线可用", detail: "没有网络也能拍题、批改、背单词")
                PrivacyPoint(icon: "person.badge.shield.checkmark.fill", tint: .dbAccent,
                             title: "未成年人保护", detail: "默认开启「学习模式」，鼓励思考而非直接抄答案")
            }

            signInSection
        }
    }

    @ViewBuilder private var signInSection: some View {
        DBCard(fill: .dbBackgroundAlt) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                Text("登录后可在多设备同步")
                    .font(.dbSubheadline)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("登录是可选的，跳过也能完整使用全部功能。")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)

                if hasResolvedSignIn {
                    Label("已记住你的选择，稍后可在「我的」里登录", systemImage: "checkmark.seal.fill")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbSuccess)
                } else {
                    appleSignInButton
                    Button("稍后再说") {
                        HapticEngine.play(.light)
                        withAnimation(.spring(duration: 0.3)) { hasResolvedSignIn = true }
                    }
                    .buttonStyle(.db(.ghost, fullWidth: true))
                }
            }
        }
    }

    @ViewBuilder private var appleSignInButton: some View {
        #if canImport(AuthenticationServices) && (os(iOS) || os(macOS))
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName]
        } onCompletion: { _ in
            // Account linking is optional in this build; record that the user
            // resolved the prompt so finishing onboarding stays one tap away.
            HapticEngine.play(.success)
            withAnimation(.spring(duration: 0.3)) { hasResolvedSignIn = true }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .clipShape(Capsule(style: .continuous))
        #else
        EmptyView()
        #endif
    }
}

private struct PrivacyPoint: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DBSpacing.md) {
            Image(systemName: icon)
                .font(.dbTitle3)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                Text(detail).font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reusable building blocks

private struct StepTitle: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            Text(title).font(.dbTitle2).foregroundStyle(Color.dbTextPrimary)
            if let subtitle {
                Text(subtitle).font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Large tappable row used for 学段 selection.
private struct OnboardingBigChoice: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DBSpacing.md) {
                Image(systemName: systemImage)
                    .font(.dbTitle2)
                    .foregroundStyle(isSelected ? Color.dbOnPrimary : tint)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? AnyShapeStyle(Color.dbHeroGradient)
                                   : AnyShapeStyle(tint.opacity(0.14)),
                        in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.dbHeadline).foregroundStyle(Color.dbTextPrimary)
                    Text(subtitle).font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.dbTitle3)
                    .foregroundStyle(isSelected ? Color.dbPrimary : Color.dbSeparator)
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity)
            .dbSurfaceStyle(
                cornerRadius: DBRadius.lg,
                fill: isSelected ? .dbPrimarySoft : .dbSurface,
                elevation: isSelected ? .medium : .low
            )
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                    .strokeBorder(isSelected ? Color.dbPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(title)，\(subtitle)")
    }
}

/// Large grade chip for the 年级 grid.
private struct OnboardingGradePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.dbBodyEmph)
                .foregroundStyle(isSelected ? Color.dbOnPrimary : Color.dbTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isSelected ? AnyShapeStyle(Color.dbHeroGradient)
                               : AnyShapeStyle(Color.dbSurface),
                    in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Color.dbSeparator, lineWidth: 1)
                )
                .dbShadow(isSelected ? .low : .none)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(title)
    }
}

/// Multi-select subject tile for the 学科 step.
private struct OnboardingSubjectTile: View {
    let subject: Subject
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color { DBSubjectColor.color(for: subject) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DBSpacing.md) {
                Image(systemName: subject.symbolName)
                    .font(.dbTitle3)
                    .foregroundStyle(isSelected ? Color.dbOnPrimary : tint)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)),
                        in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                    )
                Text(subject.displayName)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.dbBody)
                        .foregroundStyle(tint)
                }
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity)
            .dbSurfaceStyle(
                cornerRadius: DBRadius.lg,
                fill: isSelected ? .dbSurfaceRaised : .dbSurface,
                elevation: isSelected ? .medium : .low
            )
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(subject.displayName)
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
        .modelContainer(for: LearnerProfile.self, inMemory: true)
}

#Preview("Onboarding · Dark") {
    OnboardingView()
        .modelContainer(for: LearnerProfile.self, inMemory: true)
        .preferredColorScheme(.dark)
}
