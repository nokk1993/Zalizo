import Foundation
import Testing
@testable import ZalizoCore

/// Fixed UTC calendar so date math is deterministic.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

func day(_ offset: Int, from base: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> Date {
    utc.date(byAdding: .day, value: offset, to: utc.startOfDay(for: base)) ?? base
}

func approx(_ lhs: Double, _ rhs: Double, _ tolerance: Double = 0.01) -> Bool {
    abs(lhs - rhs) <= tolerance
}

// MARK: - Body metrics

@Suite("BodyMetrics")
struct BodyMetricsTests {
    @Test func bmi() {
        #expect(approx(BodyMetrics.bmi(weightKg: 80, heightCm: 180), 24.69))
        #expect(BodyMetrics.bmi(weightKg: 80, heightCm: 0) == 0)
    }

    @Test func bmrMifflinStJeor() {
        // 10·80 + 6.25·180 − 5·30 + 5 = 1780
        #expect(BodyMetrics.bmr(sex: .male, weightKg: 80, heightCm: 180, ageYears: 30) == 1780)
        // same − 161 = 1614
        #expect(BodyMetrics.bmr(sex: .female, weightKg: 80, heightCm: 180, ageYears: 30) == 1614)
    }

    @Test("TDEE activity factors", arguments: [
        (ActivityLevel.sedentary, 2447.5), (.moderate, 2759.0), (.physical, 3070.5)
    ])
    func tdee(activity: ActivityLevel, expected: Double) {
        #expect(approx(BodyMetrics.tdee(bmr: 1780, activity: activity), expected))
    }

    @Test func age() throws {
        let birth = try #require(utc.date(from: DateComponents(year: 2000, month: 6, day: 15)))
        let dayBefore = try #require(utc.date(from: DateComponents(year: 2026, month: 6, day: 14)))
        let birthday = try #require(utc.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        #expect(BodyMetrics.age(birthDate: birth, now: dayBefore, calendar: utc) == 25)
        #expect(BodyMetrics.age(birthDate: birth, now: birthday, calendar: utc) == 26)
        #expect(BodyMetrics.age(birthDate: birthday, now: birth, calendar: utc) == 0)
    }

    @Test func ffmi() throws {
        let result = try #require(BodyMetrics.ffmi(weightKg: 80, heightCm: 180, bodyFatPercent: 15))
        #expect(approx(result.leanMassKg, 68))
        #expect(approx(result.ffmi, 20.99))
        #expect(approx(result.normalizedFFMI, 20.99))
        let short = try #require(BodyMetrics.ffmi(weightKg: 70, heightCm: 170, bodyFatPercent: 10))
        #expect(approx(short.normalizedFFMI, short.ffmi + 0.61))
        #expect(BodyMetrics.ffmi(weightKg: 80, heightCm: 180, bodyFatPercent: 120) == nil)
    }
}

// MARK: - Nutrition

@Suite("Nutrition")
struct NutritionTests {
    let demo = NutritionCalculator.Input(
        sex: .male, ageYears: 30, heightCm: 180, weightKg: 80,
        activity: .sedentary, experience: .beginner, goal: .muscleGain
    )

    @Test func beginnerMuscleGainTargets() {
        let targets = NutritionCalculator.targets(for: demo)
        #expect(targets.bmr == 1780)
        #expect(approx(targets.tdee, 2447.5))
        #expect(targets.surplusPercent == 12)
        // 2447.5 × 1.12 = 2741.2 → 2740
        #expect(targets.restDay.kcal == 2740)
        #expect(targets.restDay.proteinG == 144) // 1.8 g/kg
        #expect(targets.restDay.fatG == 72) // 0.9 g/kg (> 20 % floor of 61 g)
        #expect(targets.restDay.carbsG == 379) // (2740 − 576 − 648) / 4
        #expect(targets.waterRestDayMl == 2800)
        #expect(targets.waterTrainingDayMl == 3300)
        #expect(targets.fiberG == 38)
        #expect(targets.trainingDay == targets.restDay)
    }

    @Test func experiencedSurplusIsSmaller() {
        var input = demo
        input.experience = .intermediate
        let targets = NutritionCalculator.targets(for: input)
        #expect(targets.surplusPercent == 8)
        #expect(targets.restDay.kcal == 2640) // 2447.5 × 1.08 = 2643.3
    }

    @Test("Default surplus per goal", arguments: [
        (TrainingGoal.muscleGain, ExperienceLevel.beginner, 12.0),
        (.muscleGain, .advanced, 8.0),
        (.strength, .beginner, 5.0),
        (.recomposition, .beginner, -10.0),
        (.maintenance, .intermediate, 0.0)
    ])
    func defaultSurplus(goal: TrainingGoal, experience: ExperienceLevel, expected: Double) {
        #expect(NutritionCalculator.defaultSurplusPercent(goal: goal, experience: experience) == expected)
    }

    @Test func adjustmentsAndTrainingDayBoost() {
        var input = demo
        input.adjustmentKcal = 150
        input.trainingDayCarbBoostKcal = 200
        input.surplusPercentOverride = 10
        let targets = NutritionCalculator.targets(for: input)
        // 2447.5 × 1.10 = 2692.25 → 2690 + 150
        #expect(targets.restDay.kcal == 2840)
        #expect(targets.trainingDay.kcal == 3040)
        #expect(targets.trainingDay.carbsG - targets.restDay.carbsG == 50)
        #expect(targets.trainingDay.proteinG == targets.restDay.proteinG)
    }

    @Test func fatFloorTwentyPercent() {
        let macros = NutritionCalculator.macros(kcal: 3000, weightKg: 60, proteinPerKg: 2.0, fatPerKg: 0.8)
        // 0.8 × 60 = 48 g < 20 % of 3000 kcal = 66.7 g
        #expect(macros.fatG == 67)
        #expect(macros.proteinG == 120)
        #expect(macros.carbsG == 479) // (3000 − 480 − 603) / 4 = 479.25
        #expect(macros.fatPercent >= 20)
    }

    @Test func carbsNeverNegative() {
        let macros = NutritionCalculator.macros(kcal: 800, weightKg: 100, proteinPerKg: 2.2, fatPerKg: 1.0)
        #expect(macros.carbsG == 0)
    }

    @Test func macroPercentagesSumToAboutHundred() {
        let macros = NutritionCalculator.targets(for: demo).restDay
        let sum = macros.proteinPercent + macros.fatPercent + macros.carbsPercent
        #expect(approx(sum, 100, 0.5))
    }

    @Test func waterAndFiber() {
        #expect(NutritionCalculator.waterMl(weightKg: 72.3, trainingDay: false) == 2550) // 2530.5 → 2550
        #expect(NutritionCalculator.waterMl(weightKg: 72.3, trainingDay: true) == 3050)
        #expect(NutritionCalculator.fiberG(kcal: 3000) == 42)
        #expect(Macros0.empty.proteinPercent == 0)
    }
}

private enum Macros0 {
    static let empty = NutritionCalculator.Macros(kcal: 0, proteinG: 0, fatG: 0, carbsG: 0)
}

// MARK: - Weight trend

@Suite("WeightTrend")
struct WeightTrendTests {
    @Test func movingAverageSevenDays() throws {
        let samples = (0..<10).map { WeightSample(date: day($0), weightKg: 70 + Double($0)) }
        let averaged = WeightTrend.movingAverage(samples, calendar: utc)
        #expect(averaged.count == 10)
        #expect(averaged[0].weightKg == 70)
        #expect(approx(averaged[2].weightKg, 71)) // mean(70, 71, 72)
        #expect(approx(try #require(averaged.last).weightKg, 76)) // mean(73…79)
    }

    @Test func multipleSamplesPerDayAreAveraged() {
        let samples = [
            WeightSample(date: day(0).addingTimeInterval(3600), weightKg: 70),
            WeightSample(date: day(0).addingTimeInterval(7200), weightKg: 71),
            WeightSample(date: day(1), weightKg: 72)
        ]
        let daily = WeightTrend.dailyAverages(samples, calendar: utc)
        #expect(daily.count == 2)
        #expect(daily[0].weightKg == 70.5)
        #expect(WeightTrend.movingAverage([], calendar: utc).isEmpty)
    }

    @Test func weeklyChangeOfLinearGain() throws {
        let samples = (0..<30).map { WeightSample(date: day($0), weightKg: 70 + 0.05 * Double($0)) }
        let weekly = try #require(WeightTrend.weeklyChangeKg(samples, overDays: 14, calendar: utc))
        #expect(approx(weekly, 0.35))
        #expect(WeightTrend.weeklyChangeKg(Array(samples.prefix(5)), calendar: utc) == nil)
    }

    @Test func recommendedRates() {
        #expect(WeightTrend.recommendedRatePercent(.beginner) == 0.25...0.5)
        #expect(WeightTrend.recommendedRatePercent(.advanced).upperBound == 0.25)
        #expect(approx(WeightTrend.targetRateKgPerWeek(weightKg: 70, experience: .beginner), 0.28))
        #expect(WeightTrend.targetRatePercent(.intermediate) == 0.25)
    }

    @Test func suggestedTarget() {
        // 72 + 72 × 0.4 % × 16 = 76.6 → 76.5
        #expect(WeightTrend.suggestedTargetWeight(weightKg: 72, heightCm: 178, experience: .beginner) == 76.5)
        // Capped by BMI 27 (160 cm → 69.1 kg) but always at least +1 kg
        #expect(WeightTrend.suggestedTargetWeight(weightKg: 75, heightCm: 160, experience: .beginner) == 76)
    }

    @Test func forecastExampleFromSpec() throws {
        // "з 70 кг до 78 кг при темпі 0.35 кг/тижд ≈ 23 тижні, ≈ 69 тренувань при 3/тижд"
        let start = day(0)
        let forecast = try #require(WeightTrend.forecast(currentKg: 70, targetKg: 78, kgPerWeek: 0.35, sessionsPerWeek: 3, from: start, calendar: utc))
        #expect(approx(forecast.weeks, 22.86))
        #expect(Int(forecast.weeks.rounded()) == 23)
        #expect(forecast.workouts == 69)
        #expect(forecast.targetDate == day(160))
    }

    @Test func forecastRejectsWrongDirection() {
        #expect(WeightTrend.forecast(currentKg: 70, targetKg: 78, kgPerWeek: -0.2, sessionsPerWeek: 3) == nil)
        #expect(WeightTrend.forecast(currentKg: 70, targetKg: 70, kgPerWeek: 0.2, sessionsPerWeek: 3) == nil)
        #expect(WeightTrend.forecast(currentKg: 70, targetKg: 78, kgPerWeek: 0, sessionsPerWeek: 3) == nil)
    }

    @Test func projectionStopsAtTarget() throws {
        let points = WeightTrend.projection(from: WeightSample(date: day(0), weightKg: 70), kgPerWeek: 0.5, targetKg: 72, calendar: utc)
        #expect(points.count == 5)
        #expect(try #require(points.last).weightKg == 72)
        #expect(points[1].date == day(7))
        let flat = WeightTrend.projection(from: WeightSample(date: day(0), weightKg: 70), kgPerWeek: 0, targetKg: 72, calendar: utc)
        #expect(flat.count == 1)
    }
}

// MARK: - Adaptive calories

@Suite("AdaptiveCalories")
struct AdaptiveCaloriesTests {
    func series(kgPerDay: Double, days: Int = 21) -> [WeightSample] {
        (0..<days).map { WeightSample(date: day($0), weightKg: 70 + kgPerDay * Double($0)) }
    }

    func evaluate(_ samples: [WeightSample], experience: ExperienceLevel = .beginner, goal: TrainingGoal = .muscleGain, lastCheck: Date? = nil) -> AdaptiveCalories.Evaluation {
        AdaptiveCalories.evaluate(samples: samples, experience: experience, goal: goal, lastCheck: lastCheck, now: day(20), calendar: utc)
    }

    @Test func flatWeightIsTooSlow() {
        guard case .adjust(let proposal) = evaluate(series(kgPerDay: 0)) else {
            Issue.record("expected adjustment")
            return
        }
        #expect(proposal.deltaKcal == 150)
        #expect(proposal.reason == .tooSlow)
    }

    @Test func losingWeightAddsMore() {
        guard case .adjust(let proposal) = evaluate(series(kgPerDay: -0.05)) else {
            Issue.record("expected adjustment")
            return
        }
        #expect(proposal.deltaKcal == 200)
        #expect(proposal.reason == .losing)
    }

    @Test func tooFastForNovice() {
        // 0.7 kg/week on ~71 kg ≈ 1 %/week > 0.75 %
        guard case .adjust(let proposal) = evaluate(series(kgPerDay: 0.1)) else {
            Issue.record("expected adjustment")
            return
        }
        #expect(proposal.deltaKcal == -150)
        #expect(proposal.reason == .tooFast)
    }

    @Test func experiencedThresholdIsLower() {
        // ≈0.6 %/week: fine for a novice, too fast for a trained lifter
        let samples = series(kgPerDay: 0.06)
        if case .onTrack = evaluate(samples, experience: .beginner) {} else { Issue.record("novice should be on track") }
        guard case .adjust(let proposal) = evaluate(samples, experience: .intermediate) else {
            Issue.record("expected adjustment")
            return
        }
        #expect(proposal.reason == .tooFast)
    }

    @Test func onTrack() {
        guard case .onTrack(let percent) = evaluate(series(kgPerDay: 0.035)) else {
            Issue.record("expected on track")
            return
        }
        #expect(approx(percent, 0.35, 0.02))
    }

    @Test func notDueAndNotEnoughData() {
        #expect(evaluate(series(kgPerDay: 0), lastCheck: day(15)) == .notDue)
        #expect(evaluate(series(kgPerDay: 0, days: 6)) == .notEnoughData)
        #expect(evaluate(series(kgPerDay: 0), goal: .strength) == .notDue)
        // Due again 14 days after the previous check
        if case .adjust = evaluate(series(kgPerDay: 0), lastCheck: day(6)) {} else { Issue.record("should be due") }
    }

    @Test func sparseWeighInsAreNotEnough() {
        let sparse = [0, 7, 14, 20].map { WeightSample(date: day($0), weightKg: 70) }
        #expect(evaluate(sparse) == .notEnoughData)
    }
}

// MARK: - Strength

@Suite("OneRM")
struct OneRMTests {
    @Test func epleyAndBrzycki() {
        #expect(approx(OneRM.epley(weight: 100, reps: 10), 133.33))
        #expect(approx(OneRM.brzycki(weight: 100, reps: 10), 133.33))
        #expect(approx(OneRM.epley(weight: 100, reps: 5), 116.67))
        #expect(approx(OneRM.brzycki(weight: 100, reps: 5), 112.5))
        #expect(approx(OneRM.epley(weight: 70, reps: 10), 93.33)) // spec example "зараз 93 кг"
    }

    @Test func singleRepIsTheWeight() {
        #expect(OneRM.epley(weight: 140, reps: 1) == 140)
        #expect(OneRM.brzycki(weight: 140, reps: 1) == 140)
    }

    @Test func invalidInput() {
        #expect(OneRM.epley(weight: 100, reps: 0) == 0)
        #expect(OneRM.brzycki(weight: 0, reps: 5) == 0)
        #expect(OneRM.brzycki(weight: 50, reps: 40) == OneRM.epley(weight: 50, reps: 40))
    }

    @Test func reliabilityAndRIR() {
        #expect(OneRM.estimate(weight: 60, reps: 12).isReliable)
        #expect(!OneRM.estimate(weight: 60, reps: 13).isReliable)
        // 8 reps with 2 in reserve ≈ 10RM
        #expect(OneRM.estimate(weight: 100, reps: 8, rir: 2) == OneRM.estimate(weight: 100, reps: 10))
        #expect(approx(OneRM.estimate(weight: 100, reps: 5, formula: .brzycki).value, 112.5))
    }

    @Test func percentTable() {
        #expect(OneRM.percentOfOneRM(reps: 1) == 1)
        #expect(approx(OneRM.percentOfOneRM(reps: 8, rir: 2), 0.739, 0.0001))
        #expect(approx(OneRM.percentOfOneRM(reps: 5, rir: 0), 0.863, 0.0001))
        #expect(approx(OneRM.percentOfOneRM(reps: 20), 1 / (1 + 20.0 / 30), 0.0001))
        #expect(OneRM.percentOfOneRM(reps: 0) == 1)
    }

    @Test func workingWeightRoundsDown() {
        // 100 × 73.9 % = 73.9 → 72.5 with 2.5 kg plates
        #expect(OneRM.workingWeight(oneRM: 100, reps: 8, rir: 2, step: 2.5) == 72.5)
        #expect(OneRM.workingWeight(oneRM: 100, reps: 8, rir: 2, step: 1) == 73)
    }

    @Test func relativeStrength() {
        #expect(OneRM.relativeStrength(oneRM: 120, bodyWeightKg: 80) == 1.5)
        #expect(OneRM.relativeStrength(oneRM: 120, bodyWeightKg: 0) == 0)
    }
}

@Suite("WeightRounding")
struct WeightRoundingTests {
    @Test("Rounds to step", arguments: [
        (72.4, 2.5, WeightRounding.Mode.nearest, 72.5),
        (73.7, 2.5, .nearest, 72.5),
        (74.9, 2.5, .down, 72.5),
        (75.0, 2.5, .down, 75.0),
        (70.1, 2.5, .up, 72.5),
        (70.0, 2.5, .up, 70.0),
        (23.0, 2.0, .nearest, 24.0),
        (7.0, 5.0, .nearest, 5.0)
    ])
    func rounding(weight: Double, step: Double, mode: WeightRounding.Mode, expected: Double) {
        #expect(WeightRounding.round(weight, step: step, mode: mode) == expected)
    }

    @Test func zeroStepIsIdentityAndNoNegatives() {
        #expect(WeightRounding.round(33.3, step: 0) == 33.3)
        #expect(WeightRounding.round(-3, step: 2.5) == 0)
    }

    @Test func nextDumbbell() {
        #expect(WeightRounding.nextDumbbell(after: 22, step: 2, maxKg: 40) == 24)
        #expect(WeightRounding.nextDumbbell(after: 38, step: 2, maxKg: 40) == 40)
        #expect(WeightRounding.nextDumbbell(after: 40, step: 2, maxKg: 40) == nil)
    }
}

@Suite("PlateCalculator")
struct PlateCalculatorTests {
    let plates = Defaults.plates

    @Test func hundredKilos() {
        let result = PlateCalculator.load(target: 100, barWeight: 20, plates: plates)
        #expect(result.perSide == [25, 15])
        #expect(result.isExact)
    }

    @Test func microPlates() {
        let result = PlateCalculator.load(target: 72.5, barWeight: 20, plates: plates)
        #expect(result.perSide == [25, 1.25])
        #expect(result.achievedTotal == 72.5)
    }

    @Test func impossibleWeightReportsRemainder() {
        let result = PlateCalculator.load(target: 101, barWeight: 20, plates: plates)
        #expect(result.achievedTotal == 100)
        #expect(result.remainder == 1)
        #expect(!result.isExact)
    }

    @Test func limitedPairs() {
        let result = PlateCalculator.load(target: 100, barWeight: 20, plates: [20, 10, 5], pairs: [20: 1])
        #expect(result.perSide == [20, 10, 10])
    }

    @Test func barOnly() {
        let result = PlateCalculator.load(target: 20, barWeight: 20, plates: plates)
        #expect(result.perSide.isEmpty)
        #expect(result.isExact)
        #expect(PlateCalculator.load(target: 15, barWeight: 20, plates: plates).achievedTotal == 20)
    }
}

@Suite("Warmup")
struct WarmupTests {
    @Test func classicRamp() {
        let sets = WarmupGenerator.sets(workingWeight: 100, mechanic: .compound, barWeight: 20, step: 2.5)
        #expect(sets == [
            WarmupSet(weight: 20, reps: 10), WarmupSet(weight: 40, reps: 8),
            WarmupSet(weight: 60, reps: 5), WarmupSet(weight: 80, reps: 3)
        ])
    }

    @Test func lightWorkingWeightSkipsUselessSteps() {
        let sets = WarmupGenerator.sets(workingWeight: 30, mechanic: .compound, barWeight: 20, step: 2.5)
        #expect(sets == [WarmupSet(weight: 20, reps: 10), WarmupSet(weight: 25, reps: 3)])
    }

    @Test func dumbbellsHaveNoBar() {
        let sets = WarmupGenerator.sets(workingWeight: 30, mechanic: .compound, barWeight: nil, step: 2)
        #expect(sets == [WarmupSet(weight: 12, reps: 8), WarmupSet(weight: 18, reps: 5), WarmupSet(weight: 24, reps: 3)])
    }

    @Test func isolationHasNoWarmup() {
        #expect(WarmupGenerator.sets(workingWeight: 30, mechanic: .isolation, barWeight: nil, step: 2).isEmpty)
        #expect(WarmupGenerator.sets(workingWeight: 0, mechanic: .compound, barWeight: 20, step: 2.5).isEmpty)
    }
}

@Suite("Volume")
struct VolumeTests {
    @Test func tonnageIgnoresWarmups() {
        let sets = [
            Volume.SetSample(weight: 20, reps: 10, isWarmup: true),
            Volume.SetSample(weight: 70, reps: 10),
            Volume.SetSample(weight: 70, reps: 9)
        ]
        #expect(Volume.tonnage(sets) == 1330)
    }

    @Test func fractionalSetCounting() {
        let totals = Volume.setsPerMuscle([
            .init(primary: [.chest], secondary: [.triceps, .shoulders], workingSets: 4),
            .init(primary: [.triceps], secondary: [], workingSets: 3),
            .init(primary: [.chest], secondary: [.chest], workingSets: 2) // secondary duplicate ignored
        ])
        #expect(totals[.chest] == 6)
        #expect(totals[.triceps] == 5)
        #expect(totals[.shoulders] == 2)
        #expect(totals[.back] == nil)
    }

    @Test("Volume zones", arguments: [(9.5, Volume.Zone.low), (10, .optimal), (20, .optimal), (21, .high)])
    func zones(sets: Double, zone: Volume.Zone) {
        #expect(Volume.zone(weeklySets: sets) == zone)
    }
}
