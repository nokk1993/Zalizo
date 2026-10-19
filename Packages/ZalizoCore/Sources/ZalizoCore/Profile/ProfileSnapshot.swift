import Foundation

/// Value-type copy of everything the user tells the app about themselves.
/// Editing screens work on a snapshot; changes are written to the database only after confirmation.
public struct ProfileSnapshot: Equatable, Sendable {
    public var sex: Sex = Defaults.sex
    public var birthDate: Date?
    public var heightCm: Double = Defaults.heightCm
    public var weightKg: Double = Defaults.weightKg
    public var experience: ExperienceLevel = Defaults.experience
    public var goal: TrainingGoal = Defaults.goal
    public var trainingDays: [Weekday] = Defaults.trainingDays
    public var sessionMinutes: Int = Defaults.sessionMinutes
    public var activity: ActivityLevel = Defaults.activity
    public var equipment: Set<Equipment> = Set(Defaults.equipment)
    public var dumbbellMaxKg: Double = Defaults.dumbbellMaxKg
    public var hasMicroPlates = true
    public var limitations: Set<InjuryArea> = []
    public var dietExclusions: Set<DietExclusion> = []
    public var mealsPerDay: Int = Defaults.mealsPerDay
    public var budget: FoodBudget = Defaults.budget
    /// nil → the app suggests a target.
    public var targetWeightKg: Double?
    public var bodyFatPercent: Double?
    public var proteinPerKg: Double = Defaults.proteinPerKg
    public var fatPerKg: Double = Defaults.fatPerKg
    public var surplusPercentOverride: Double?
    public var adjustmentKcal = 0
    public var trainingDayCarbBoostKcal = 0

    public init() {}

    public func ageYears(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let birthDate else { return Defaults.ageYears }
        return BodyMetrics.age(birthDate: birthDate, now: now, calendar: calendar)
    }

    public var sessionsPerWeek: Int { max(1, trainingDays.count) }

    public func nutritionInput(now: Date = .now, calendar: Calendar = .current) -> NutritionCalculator.Input {
        NutritionCalculator.Input(
            sex: sex, ageYears: ageYears(now: now, calendar: calendar), heightCm: heightCm, weightKg: weightKg,
            activity: activity, experience: experience, goal: goal,
            proteinPerKg: proteinPerKg, fatPerKg: fatPerKg, surplusPercentOverride: surplusPercentOverride,
            adjustmentKcal: adjustmentKcal, trainingDayCarbBoostKcal: trainingDayCarbBoostKcal
        )
    }
}

/// Everything shown on the onboarding summary and the "Норми і прогноз" screen.
public struct PlanSummary: Equatable, Sendable {
    public let targets: NutritionCalculator.Targets
    public let bmi: Double
    public let targetWeightKg: Double
    /// True when the user did not set a target and the app suggested one.
    public let isTargetSuggested: Bool
    /// Planned weekly change, kg (0 for maintenance/recomposition).
    public let kgPerWeek: Double
    public let ratePercent: Double
    public let recommendedRatePercent: ClosedRange<Double>
    public let forecast: WeightTrend.Forecast?
    public let recommendedProgramSlug: String
}

public enum PlanCalculator {
    /// Planned pace for the goal, % of body weight per week.
    public static func ratePercent(goal: TrainingGoal, experience: ExperienceLevel) -> Double {
        switch goal {
        case .muscleGain: WeightTrend.targetRatePercent(experience)
        case .strength: WeightTrend.targetRatePercent(experience) / 2
        case .recomposition, .maintenance: 0
        }
    }

    public static func summary(for profile: ProfileSnapshot, now: Date = .now, calendar: Calendar = .current) -> PlanSummary {
        let targets = NutritionCalculator.targets(for: profile.nutritionInput(now: now, calendar: calendar))
        let rate = ratePercent(goal: profile.goal, experience: profile.experience)
        let kgPerWeek = (profile.weightKg * rate / 100 * 100).rounded() / 100
        let target = profile.targetWeightKg
            ?? (rate > 0
                ? WeightTrend.suggestedTargetWeight(weightKg: profile.weightKg, heightCm: profile.heightCm, experience: profile.experience)
                : profile.weightKg)
        let forecast = WeightTrend.forecast(
            currentKg: profile.weightKg, targetKg: target, kgPerWeek: kgPerWeek,
            sessionsPerWeek: profile.sessionsPerWeek, from: now, calendar: calendar
        )
        return PlanSummary(
            targets: targets,
            bmi: BodyMetrics.bmi(weightKg: profile.weightKg, heightCm: profile.heightCm),
            targetWeightKg: target,
            isTargetSuggested: profile.targetWeightKg == nil,
            kgPerWeek: kgPerWeek,
            ratePercent: rate,
            recommendedRatePercent: WeightTrend.recommendedRatePercent(profile.experience),
            forecast: forecast,
            recommendedProgramSlug: ProgramCatalog.recommendedSlug(daysPerWeek: profile.trainingDays.count, experience: profile.experience)
        )
    }

    /// What changes between two summaries - shown to the user before applying profile edits.
    public static func changes(from old: PlanSummary, to new: PlanSummary) -> [PlanChange] {
        var result: [PlanChange] = []
        func add(_ field: PlanChange.Field, _ before: Double?, _ after: Double?) {
            if before != after { result.append(PlanChange(field: field, old: before, new: after)) }
        }
        add(.kcal, Double(old.targets.restDay.kcal), Double(new.targets.restDay.kcal))
        add(.trainingDayKcal, Double(old.targets.trainingDay.kcal), Double(new.targets.trainingDay.kcal))
        add(.protein, Double(old.targets.restDay.proteinG), Double(new.targets.restDay.proteinG))
        add(.fat, Double(old.targets.restDay.fatG), Double(new.targets.restDay.fatG))
        add(.carbs, Double(old.targets.restDay.carbsG), Double(new.targets.restDay.carbsG))
        add(.water, Double(old.targets.waterRestDayMl), Double(new.targets.waterRestDayMl))
        add(.targetWeight, old.targetWeightKg, new.targetWeightKg)
        add(.weeklyRate, old.kgPerWeek, new.kgPerWeek)
        add(.forecastWeeks, old.forecast.map { ($0.weeks * 10).rounded() / 10 }, new.forecast.map { ($0.weeks * 10).rounded() / 10 })
        if old.recommendedProgramSlug != new.recommendedProgramSlug {
            result.append(PlanChange(field: .program, old: nil, new: nil))
        }
        return result
    }
}

public struct PlanChange: Equatable, Sendable {
    public enum Field: String, Sendable {
        case kcal, trainingDayKcal, protein, fat, carbs, water, targetWeight, weeklyRate, forecastWeeks, program
    }

    public let field: Field
    public let old: Double?
    public let new: Double?
}

/// Stable slugs of the built-in programs (seeded in stage 5) and the onboarding recommendation.
public enum ProgramCatalog {
    public static let massSplit3 = "mass-split-3"
    public static let fullBody3 = "full-body-3"
    public static let upperLower4 = "upper-lower-4"
    public static let pushPullLegs3 = "ppl-3"
    public static let pushPullLegs6 = "ppl-6"

    public static func recommendedSlug(daysPerWeek: Int, experience: ExperienceLevel) -> String {
        switch daysPerWeek {
        case ...2: fullBody3
        case 3: massSplit3 // DEFAULT program from the spec
        case 4, 5: upperLower4
        default: pushPullLegs6
        }
    }
}

/// Main lifts the user may enter in onboarding to seed working weights.
public enum KeyLift: String, CaseIterable, Sendable {
    case benchPress = "barbell-bench-press"
    case squat = "barbell-back-squat"
    case romanianDeadlift = "romanian-deadlift"
    case overheadPress = "overhead-press"
    case barbellRow = "barbell-bent-over-row"
}

/// A known set ("70 kg × 10") used to estimate a starting 1RM.
public struct LiftResult: Equatable, Sendable {
    public var weightKg: Double
    public var reps: Int

    public init(weightKg: Double, reps: Int) {
        self.weightKg = weightKg
        self.reps = reps
    }

    public var isValid: Bool { weightKg > 0 && reps > 0 }

    public func estimatedOneRM(formula: OneRMFormula = .epley) -> OneRM.Estimate {
        OneRM.estimate(weight: weightKg, reps: reps, formula: formula)
    }
}
