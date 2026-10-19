import SwiftData
import SwiftUI
import ZalizoCore

/// Creates the onboarding model once and hosts the flow.
struct OnboardingContainer: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @State private var model: OnboardingModel?

    var body: some View {
        Group {
            if let model {
                OnboardingFlowView(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { ZalBackground() }
            }
        }
        .task {
            if model == nil {
                model = OnboardingModel(context: context, profile: profile)
            }
        }
    }
}

struct OnboardingFlowView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    if let hero = model.step.hero {
                        ScreenHeader(title: Text(hero.light), accent: Text(hero.bold))
                    }
                    content
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xl)
                .id(model.step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top) { header }
            .safeAreaInset(edge: .bottom) { footer }
            .zalScreen()
            .navigationTitle(Text(model.step.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Крок \(model.step.rawValue + 1) з \(OnboardingStep.allCases.count)")
                        .eyebrow()
                        .monospacedDigit()
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .welcome: WelcomeSection()
        case .body: BodySection(snapshot: $model.snapshot)
        case .goal: GoalSection(snapshot: $model.snapshot)
        case .schedule: ScheduleSection(snapshot: $model.snapshot)
        case .activity: ActivitySection(snapshot: $model.snapshot)
        case .equipment: EquipmentSection(snapshot: $model.snapshot, dumbbellStepKg: $model.dumbbellStepKg)
        case .limitations: LimitationsSection(snapshot: $model.snapshot)
        case .nutrition: NutritionPreferencesSection(snapshot: $model.snapshot)
        case .target: TargetWeightSection(snapshot: $model.snapshot)
        case .lifts: LiftsSection(knowsLifts: $model.knowsLifts, lifts: $model.lifts)
        case .summary:
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("Норми перераховуються автоматично, коли змінюється вага або дані профілю")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                PlanSummaryCard(summary: model.summary, snapshot: model.snapshot)
            }
        }
    }

    private var header: some View {
        OnboardingProgressBar(progress: model.progress)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background {
                LinearGradient(colors: [Theme.Palette.canvasTop, Theme.Palette.canvasTop.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
            }
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                if model.canGoBack {
                    Button {
                        withAnimation(.snappy) { model.back() }
                    } label: {
                        Text("Назад").frame(minWidth: 72, minHeight: 36)
                    }
                    .buttonStyle(.glass)
                }
                Button {
                    withAnimation(.snappy) {
                        if model.step == .summary {
                            model.finish()
                        } else {
                            model.next()
                        }
                    }
                } label: {
                    Text(model.step == .summary ? "Почати" : "Далі")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.zalPrimary)
                .disabled(!model.canProceed)
            }
            if model.step.isSkippable {
                Button("Пропустити") {
                    withAnimation(.snappy) { model.skip() }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(minHeight: 32)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
        .background {
            LinearGradient(colors: [Theme.Palette.canvasBottom.opacity(0), Theme.Palette.canvasBottom.opacity(0.92)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Thin lime progress capsule with a glow.
private struct OnboardingProgressBar: View {
    let progress: Double

    private var fraction: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.1))
            Capsule()
                .fill(Theme.Palette.accent)
                .scaleEffect(x: max(fraction, 0.02), y: 1, anchor: .leading)
                .shadow(color: Theme.Palette.accent.opacity(0.7), radius: 6)
        }
        .frame(height: 6)
        .animation(.snappy, value: fraction)
        .accessibilityElement()
        .accessibilityLabel("Прогрес анкети")
        .accessibilityValue(Text("\(Int((fraction * 100).rounded())) %"))
    }
}

/// Light line + bold accent line shown above each question step.
private extension OnboardingStep {
    struct Hero {
        let light: LocalizedStringResource
        let bold: LocalizedStringResource
    }

    var hero: Hero? {
        switch self {
        case .welcome: nil
        case .body: Hero(light: "Розкажи", bold: "про себе")
        case .goal: Hero(light: "Твій досвід", bold: "і ціль")
        case .schedule: Hero(light: "Коли", bold: "тренуєшся?")
        case .activity: Hero(light: "Скільки рухаєшся", bold: "поза залом?")
        case .equipment: Hero(light: "Що є", bold: "у залі?")
        case .limitations: Hero(light: "Є обмеження", bold: "чи травми?")
        case .nutrition: Hero(light: "Як ти", bold: "харчуєшся?")
        case .target: Hero(light: "Цільова", bold: "вага")
        case .lifts: Hero(light: "Стартові", bold: "робочі ваги")
        case .summary: Hero(light: "Твій план", bold: "готовий")
        }
    }
}
