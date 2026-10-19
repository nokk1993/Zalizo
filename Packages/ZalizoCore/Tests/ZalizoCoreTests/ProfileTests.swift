import Foundation
import Testing
@testable import ZalizoCore

@Suite("Profile & plan summary")
struct ProfileTests {
    /// Fictional demo person.
    func demo() throws -> ProfileSnapshot {
        var profile = ProfileSnapshot()
        profile.sex = .male
        let birthDate = try #require(utc.date(from: DateComponents(year: 1996, month: 1, day: 10)))
        profile.birthDate = birthDate
        profile.heightCm = 180
        profile.weightKg = 70
        profile.experience = .beginner
        profile.goal = .muscleGain
        profile.activity = .sedentary
        profile.trainingDays = [.monday, .wednesday, .friday]
        return profile
    }

    var now: Date { day(0) }

    @Test func defaultAgeWhenBirthDateSkipped() {
        #expect(ProfileSnapshot().ageYears() == Defaults.ageYears)
    }

    @Test func summaryMatchesManualCalculation() throws {
        let profile = try demo()
        let age = profile.ageYears(now: now, calendar: utc)
        #expect(age == 30) // 2026-09 vs 1996-01
        let summary = PlanCalculator.summary(for: profile, now: now, calendar: utc)
        // BMR = 700 + 1125 − 150 + 5 = 1680; TDEE = 2310; ×1.12 = 2587.2 → 2590
        #expect(summary.targets.bmr == 1680)
        #expect(summary.targets.restDay.kcal == 2590)
        #expect(summary.targets.restDay.proteinG == 126)
        #expect(summary.targets.restDay.fatG == 63)
        // 0.4 % of 70 kg = 0.28 kg/week
        #expect(summary.kgPerWeek == 0.28)
        // Suggested: 70 + 0.28 × 16 = 74.48 → 74.5
        #expect(summary.isTargetSuggested)
        #expect(summary.targetWeightKg == 74.5)
        let forecast = try #require(summary.forecast)
        #expect(approx(forecast.weeks, 16.07))
        #expect(forecast.workouts == 48)
        #expect(summary.recommendedProgramSlug == ProgramCatalog.massSplit3)
    }

    @Test func explicitTargetIsUsed() throws {
        var profile = try demo()
        profile.targetWeightKg = 78
        let summary = PlanCalculator.summary(for: profile, now: now, calendar: utc)
        #expect(!summary.isTargetSuggested)
        #expect(summary.targetWeightKg == 78)
        #expect(try #require(summary.forecast).workouts == 86) // 8 / 0.28 = 28.6 weeks × 3
    }

    @Test func maintenanceHasNoForecast() throws {
        var profile = try demo()
        profile.goal = .maintenance
        let summary = PlanCalculator.summary(for: profile, now: now, calendar: utc)
        #expect(summary.kgPerWeek == 0)
        #expect(summary.targetWeightKg == 70)
        #expect(summary.forecast == nil)
    }

    @Test func targetBelowCurrentWeightGivesNoForecast() throws {
        var profile = try demo()
        profile.targetWeightKg = 65
        #expect(PlanCalculator.summary(for: profile, now: now, calendar: utc).forecast == nil)
    }

    @Test func changesListOnlyDifferences() throws {
        let profile = try demo()
        var heavier = profile
        heavier.weightKg = 75
        let old = PlanCalculator.summary(for: profile, now: now, calendar: utc)
        let new = PlanCalculator.summary(for: heavier, now: now, calendar: utc)
        let fields = PlanCalculator.changes(from: old, to: new).map(\.field)
        #expect(fields.contains(.kcal))
        #expect(fields.contains(.protein))
        #expect(fields.contains(.water))
        #expect(!fields.contains(.program))
        #expect(PlanCalculator.changes(from: old, to: old).isEmpty)

        let kcal = try #require(PlanCalculator.changes(from: old, to: new).first { $0.field == .kcal })
        #expect(kcal.old == 2590)
        #expect(try #require(kcal.new) > 2590)
    }

    @Test func programChangeWhenDaysChange() throws {
        let profile = try demo()
        var fourDays = profile
        fourDays.trainingDays = [.monday, .tuesday, .thursday, .friday]
        let changes = PlanCalculator.changes(
            from: PlanCalculator.summary(for: profile, now: now, calendar: utc),
            to: PlanCalculator.summary(for: fourDays, now: now, calendar: utc)
        )
        #expect(changes.contains { $0.field == .program })
    }

    @Test("Program recommendation", arguments: [
        (2, ProgramCatalog.fullBody3), (3, ProgramCatalog.massSplit3), (4, ProgramCatalog.upperLower4),
        (5, ProgramCatalog.upperLower4), (6, ProgramCatalog.pushPullLegs6)
    ])
    func recommendation(days: Int, slug: String) {
        #expect(ProgramCatalog.recommendedSlug(daysPerWeek: days, experience: .beginner) == slug)
    }

    @Test func strengthGoalGainsSlower() {
        #expect(PlanCalculator.ratePercent(goal: .strength, experience: .beginner) == 0.2)
        #expect(PlanCalculator.ratePercent(goal: .recomposition, experience: .beginner) == 0)
    }
}
