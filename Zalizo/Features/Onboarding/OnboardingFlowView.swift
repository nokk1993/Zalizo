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
                content
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xl)
                    .id(model.step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top) { header }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle(Text(model.step.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.step.isSkippable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Пропустити") {
                            withAnimation(.snappy) { model.skip() }
                        }
                    }
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
                QuestionHeader(title: "Твій план готовий", subtitle: "Норми перераховуються автоматично, коли змінюється вага або дані профілю")
                PlanSummaryCard(summary: model.summary, snapshot: model.snapshot)
            }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ProgressView(value: model.progress)
                .tint(.accentColor)
                .animation(.snappy, value: model.progress)
            Text("Крок \(model.step.rawValue + 1) з \(OnboardingStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.m) {
            if model.canGoBack {
                Button {
                    withAnimation(.snappy) { model.back() }
                } label: {
                    Text("Назад").frame(maxWidth: .infinity, minHeight: 44)
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
                    .bold()
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .disabled(!model.canProceed)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
    }
}
