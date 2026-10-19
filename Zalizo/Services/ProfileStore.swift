import Foundation
import SwiftData
import ZalizoCore

/// Reads/writes the single profile and settings rows and converts them to/from `ProfileSnapshot`.
@MainActor
enum ProfileStore {
    static func profile(in context: ModelContext) -> UserProfile? {
        try? context.fetch(FetchDescriptor<UserProfile>()).first
    }

    static func settings(in context: ModelContext) -> AppSettings? {
        try? context.fetch(FetchDescriptor<AppSettings>()).first
    }

    static func latestWeight(in context: ModelContext) -> BodyWeightEntry? {
        var descriptor = FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func snapshot(of profile: UserProfile, currentWeightKg: Double?) -> ProfileSnapshot {
        var snapshot = ProfileSnapshot()
        snapshot.sex = profile.sex
        snapshot.birthDate = profile.birthDate
        snapshot.heightCm = profile.heightCm
        snapshot.weightKg = currentWeightKg ?? Defaults.weightKg
        snapshot.experience = profile.experience
        snapshot.goal = profile.goal
        snapshot.trainingDays = profile.weekdays.isEmpty ? Defaults.trainingDays : profile.weekdays
        snapshot.sessionMinutes = profile.sessionMinutes
        snapshot.activity = profile.activity
        snapshot.equipment = profile.equipment
        snapshot.dumbbellMaxKg = profile.dumbbellMaxKg
        snapshot.hasMicroPlates = profile.hasMicroPlates
        snapshot.limitations = profile.limitations
        snapshot.dietExclusions = profile.dietExclusions
        snapshot.mealsPerDay = profile.mealsPerDay
        snapshot.budget = profile.budget
        snapshot.targetWeightKg = profile.targetWeightKg
        snapshot.bodyFatPercent = profile.bodyFatPercent
        snapshot.proteinPerKg = profile.proteinPerKg
        snapshot.fatPerKg = profile.fatPerKg
        snapshot.surplusPercentOverride = profile.surplusPercentOverride
        snapshot.adjustmentKcal = profile.calorieAdjustmentKcal
        snapshot.trainingDayCarbBoostKcal = profile.trainingDayCarbBoostKcal
        return snapshot
    }

    static func snapshot(in context: ModelContext) -> ProfileSnapshot {
        guard let profile = profile(in: context) else { return ProfileSnapshot() }
        return snapshot(of: profile, currentWeightKg: latestWeight(in: context)?.weightKg)
    }

    /// Writes the snapshot into the model. Body weight goes into today's weight entry.
    static func apply(_ snapshot: ProfileSnapshot, to profile: UserProfile, context: ModelContext, includeWeight: Bool = true, now: Date = .now) {
        profile.sex = snapshot.sex
        profile.birthDate = snapshot.birthDate
        profile.heightCm = snapshot.heightCm
        profile.experience = snapshot.experience
        profile.goal = snapshot.goal
        profile.weekdays = snapshot.trainingDays
        profile.sessionMinutes = snapshot.sessionMinutes
        profile.activity = snapshot.activity
        profile.equipment = snapshot.equipment
        profile.dumbbellMaxKg = snapshot.dumbbellMaxKg
        profile.hasMicroPlates = snapshot.hasMicroPlates
        profile.limitations = snapshot.limitations
        profile.dietExclusions = snapshot.dietExclusions
        profile.mealsPerDay = snapshot.mealsPerDay
        profile.budget = snapshot.budget
        profile.targetWeightKg = snapshot.targetWeightKg
        profile.bodyFatPercent = snapshot.bodyFatPercent
        profile.proteinPerKg = snapshot.proteinPerKg
        profile.fatPerKg = snapshot.fatPerKg
        profile.surplusPercentOverride = snapshot.surplusPercentOverride
        profile.calorieAdjustmentKcal = snapshot.adjustmentKcal
        profile.trainingDayCarbBoostKcal = snapshot.trainingDayCarbBoostKcal

        if includeWeight, latestWeight(in: context)?.weightKg != snapshot.weightKg {
            recordWeight(snapshot.weightKg, on: now, context: context)
        }
        if let settings = settings(in: context) {
            // Without 1.25 kg plates the smallest barbell jump is 5 kg.
            settings.barbellStepKg = snapshot.hasMicroPlates ? 2.5 : 5
        }
    }

    /// One weight entry per day: updates today's entry or inserts a new one.
    static func recordWeight(_ kg: Double, on date: Date = .now, context: ModelContext, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        let descriptor = FetchDescriptor<BodyWeightEntry>(predicate: #Predicate { $0.date >= start && $0.date < end })
        if let existing = try? context.fetch(descriptor).first {
            existing.weightKg = kg
            existing.date = date
        } else {
            context.insert(BodyWeightEntry(date: date, weightKg: kg))
        }
        HealthService.saveWeight(kg, date: date)
    }

    /// Replaces the onboarding baselines ("bench 70 kg × 10").
    static func saveBaselines(_ baselines: [KeyLift: LiftResult], context: ModelContext) {
        if let existing = try? context.fetch(FetchDescriptor<StrengthBaseline>()) {
            existing.forEach(context.delete)
        }
        for (lift, value) in baselines where value.isValid {
            context.insert(StrengthBaseline(exerciseSlug: lift.rawValue, weightKg: value.weightKg, reps: value.reps))
        }
    }

    static func baselines(in context: ModelContext) -> [KeyLift: LiftResult] {
        let rows = (try? context.fetch(FetchDescriptor<StrengthBaseline>())) ?? []
        var result: [KeyLift: LiftResult] = [:]
        for row in rows {
            if let lift = KeyLift(rawValue: row.exerciseSlug) {
                result[lift] = LiftResult(weightKg: row.weightKg, reps: row.reps)
            }
        }
        return result
    }
}
