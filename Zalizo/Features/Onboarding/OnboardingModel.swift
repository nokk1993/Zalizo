import Foundation
import Observation
import SwiftData
import ZalizoCore

enum OnboardingStep: Int, CaseIterable, Comparable {
    case welcome, body, goal, schedule, activity, equipment, limitations, nutrition, target, lifts, summary

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .welcome: "Вітаємо"
        case .body: "Про тебе"
        case .goal: "Досвід і ціль"
        case .schedule: "Розклад"
        case .activity: "Активність"
        case .equipment: "Обладнання"
        case .limitations: "Обмеження"
        case .nutrition: "Харчування"
        case .target: "Цільова вага"
        case .lifts: "Стартові ваги"
        case .summary: "Твій план"
        }
    }

    /// Welcome and summary have nothing to skip.
    var isSkippable: Bool { self != .welcome && self != .summary }
}

/// Drives the first-launch questionnaire. Every step is persisted, so the flow resumes where it stopped.
@MainActor
@Observable
final class OnboardingModel {
    var step: OnboardingStep
    var snapshot: ProfileSnapshot
    var dumbbellStepKg: Double
    var knowsLifts: Bool
    var lifts: [KeyLift: LiftResult]

    private let context: ModelContext
    private let profile: UserProfile

    init(context: ModelContext, profile: UserProfile) {
        self.context = context
        self.profile = profile
        self.step = OnboardingStep(rawValue: profile.onboardingStep) ?? .welcome
        self.snapshot = ProfileStore.snapshot(of: profile, currentWeightKg: ProfileStore.latestWeight(in: context)?.weightKg)
        self.dumbbellStepKg = ProfileStore.settings(in: context)?.dumbbellStepKg ?? Defaults.dumbbellStepKg
        let saved = ProfileStore.baselines(in: context)
        self.lifts = saved
        self.knowsLifts = !saved.isEmpty
    }

    var progress: Double {
        Double(step.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }

    var summary: PlanSummary { PlanCalculator.summary(for: snapshot) }

    var canGoBack: Bool { step != .welcome }

    var canProceed: Bool {
        switch step {
        case .schedule: !snapshot.trainingDays.isEmpty
        default: true
        }
    }

    func next() {
        persist()
        guard let following = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = following
        persist()
    }

    func back() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
        persist()
    }

    /// "Пропустити": defaults for this step's questions, then continue.
    func skip() {
        let defaults = ProfileSnapshot()
        switch step {
        case .body:
            snapshot.sex = defaults.sex
            snapshot.birthDate = nil
            snapshot.heightCm = defaults.heightCm
            snapshot.weightKg = defaults.weightKg
        case .goal:
            snapshot.experience = defaults.experience
            snapshot.goal = defaults.goal
        case .schedule:
            snapshot.trainingDays = defaults.trainingDays
            snapshot.sessionMinutes = defaults.sessionMinutes
        case .activity:
            snapshot.activity = defaults.activity
        case .equipment:
            snapshot.equipment = defaults.equipment
            snapshot.dumbbellMaxKg = defaults.dumbbellMaxKg
            snapshot.hasMicroPlates = defaults.hasMicroPlates
            dumbbellStepKg = Defaults.dumbbellStepKg
        case .limitations:
            snapshot.limitations = []
        case .nutrition:
            snapshot.dietExclusions = []
            snapshot.mealsPerDay = defaults.mealsPerDay
            snapshot.budget = defaults.budget
        case .target:
            snapshot.targetWeightKg = nil
        case .lifts:
            knowsLifts = false
            lifts = [:]
        case .welcome, .summary:
            break
        }
        next()
    }

    func finish() {
        persist()
        if profile.activeProgramID == nil {
            ProgramStore.activate(seedSlug: summary.recommendedProgramSlug, context: context)
        }
        profile.onboardingCompleted = true
        profile.blockStartDate = profile.blockStartDate ?? .now
        save()
    }

    private func persist() {
        // Weight is recorded only once the user has actually seen the body step.
        ProfileStore.apply(snapshot, to: profile, context: context, includeWeight: step > .body)
        profile.onboardingStep = step.rawValue
        ProfileStore.settings(in: context)?.dumbbellStepKg = dumbbellStepKg
        ProfileStore.saveBaselines(knowsLifts ? lifts : [:], context: context)
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // SwiftData autosave retries later; nothing the user can do here.
            Log.data.error("Onboarding save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
