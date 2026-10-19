import Foundation
import Testing
@testable import ZalizoCore

@Suite("ProgressionEngine")
struct ProgressionEngineTests {
    let settings = LoadSettings()
    let bench = ExercisePlan(sets: 4, repMin: 6, repMax: 8, targetRIR: 2, load: .barbell, region: .upper, mechanic: .compound)
    let squat = ExercisePlan(sets: 4, repMin: 6, repMax: 8, targetRIR: 1, load: .barbell, region: .lower, mechanic: .compound)

    func session(_ weight: Double, _ reps: [Int], daysAgo: Int = 3, deload: Bool = false) -> ExerciseHistoryEntry {
        ExerciseHistoryEntry(date: day(-daysAgo), sets: reps.map { PerformedSet(weight: weight, reps: $0) }, wasDeload: deload)
    }

    func prescribe(_ plan: ExercisePlan, _ history: [ExerciseHistoryEntry], baseline: Double? = nil) -> Prescription {
        ProgressionEngine.prescribe(plan: plan, history: history, baselineOneRM: baseline, settings: settings)
    }

    @Test func calibrationWithoutAnyData() {
        let result = prescribe(bench, [])
        #expect(result.kind == .calibrate)
        #expect(result.weight == 0)
        #expect(result.reps == [6, 6, 6, 6])
    }

    @Test func startFromOnboardingBaseline() {
        // 70 × 10 → 1RM 93.3; 6 reps @ 2 RIR ≈ 8RM ≈ 78.6 % → 73.4 → 72.5 kg
        let result = prescribe(bench, [], baseline: OneRM.epley(weight: 70, reps: 10))
        #expect(result.kind == .fromBaseline)
        #expect(result.weight == 72.5)
        #expect(result.reps == [6, 6, 6, 6])
    }

    @Test func baselineNeverBelowEmptyBar() {
        let result = prescribe(bench, [], baseline: 15)
        #expect(result.weight == 20)
    }

    @Test func topOfRangeInAllSetsAddsWeightUpperBody() throws {
        let result = prescribe(bench, [session(70, [8, 8, 8, 8])])
        #expect(result.kind == .increaseWeight)
        #expect(result.weight == 72.5)
        #expect(result.weightChange == 2.5)
        #expect(result.reps == [6, 6, 6, 6])
        #expect(try #require(result.last).topWeight == 70)
    }

    @Test func lowerBodyJumpsFiveKilos() {
        let result = prescribe(squat, [session(100, [8, 9, 8, 8])])
        #expect(result.kind == .increaseWeight)
        #expect(result.weight == 105)
    }

    @Test func withinRangeAddsOneRepToWeakestSet() {
        let result = prescribe(bench, [session(70, [8, 8, 7, 6])])
        #expect(result.kind == .addReps)
        #expect(result.weight == 70)
        #expect(result.reps == [8, 8, 7, 7])
    }

    @Test func firstMissRepeatsWeight() {
        let result = prescribe(bench, [session(70, [7, 6, 5, 5]), session(67.5, [8, 8, 8, 8], daysAgo: 7)])
        #expect(result.kind == .repeatWeight)
        #expect(result.weight == 70)
        #expect(result.reps == [6, 6, 6, 6])
    }

    @Test func twoMissesInARowIsAStall() {
        let result = prescribe(bench, [session(70, [6, 5, 5, 4]), session(70, [6, 6, 5, 5], daysAgo: 7)])
        #expect(result.kind == .stall)
        #expect(result.weight == 62.5) // 70 − 10 % = 63 → 62.5
        #expect(result.weightChange == -7.5)
    }

    @Test func fewerSetsThanPlannedDoesNotProgress() {
        let result = prescribe(bench, [session(70, [8, 8, 8])])
        #expect(result.kind == .repeatWeight)
        #expect(result.weight == 70)
    }

    @Test func onlyTopWeightSetsCount() {
        let mixed = ExerciseHistoryEntry(date: day(-3), sets: [
            PerformedSet(weight: 70, reps: 8), PerformedSet(weight: 70, reps: 8),
            PerformedSet(weight: 70, reps: 8), PerformedSet(weight: 70, reps: 8),
            PerformedSet(weight: 60, reps: 12) // back-off set
        ])
        #expect(prescribe(bench, [mixed]).kind == .increaseWeight)
    }

    @Test func deloadSessionsAreIgnored() {
        let result = prescribe(bench, [session(70, [8, 8], daysAgo: 2, deload: true), session(70, [8, 8, 7, 7], daysAgo: 9)])
        #expect(result.kind == .addReps)
        #expect(result.reps == [8, 8, 8, 7]) // +1 on the first weakest set
    }

    @Test func dumbbellsGoToNextDumbbell() {
        let plan = ExercisePlan(sets: 3, repMin: 8, repMax: 10, load: .dumbbell(stepKg: 2, maxKg: 40), mechanic: .compound)
        #expect(prescribe(plan, [session(30, [10, 10, 10])]).weight == 32)
        let atMax = prescribe(plan, [session(40, [10, 10, 10])])
        #expect(atMax.kind == .addReps)
        #expect(atMax.weight == 40)
        #expect(atMax.reps == [11, 10, 10])
    }

    @Test func machineIsolationSmallJump() {
        let plan = ExercisePlan(sets: 3, repMin: 12, repMax: 15, load: .machine(stepKg: 5), mechanic: .isolation)
        #expect(prescribe(plan, [session(40, [15, 15, 15])]).weight == 42.5)
        let compound = ExercisePlan(sets: 3, repMin: 10, repMax: 12, load: .machine(stepKg: 5), mechanic: .compound)
        #expect(prescribe(compound, [session(100, [12, 12, 12])]).weight == 105)
    }

    @Test func incrementOverride() {
        var plan = bench
        plan.incrementOverrideKg = 1.25
        #expect(prescribe(plan, [session(70, [8, 8, 8, 8])]).weight == 71.25)
    }

    @Test func bodyweightAddsBeltWeightAfterTopOfRange() {
        let pullUp = ExercisePlan(sets: 4, repMin: 6, repMax: 10, load: .bodyweight)
        let result = prescribe(pullUp, [session(0, [10, 10, 10, 10])])
        #expect(result.kind == .increaseWeight)
        #expect(result.weight == 2.5)
        #expect(prescribe(pullUp, [session(0, [9, 8, 7, 6])]).reps == [9, 8, 7, 7])
    }

    @Test func timedHolds() {
        let plank = ExercisePlan(sets: 3, repMin: 45, repMax: 60, load: .timed)
        #expect(prescribe(plank, [session(0, [60, 60, 60])]).reps == [70, 70, 70])
        #expect(prescribe(plank, [session(0, [50, 45, 40])]).reps == [50, 45, 45])
        #expect(prescribe(plank, []).kind == .calibrate)
    }

    @Test func bestEstimatedOneRMFromHistory() {
        let result = prescribe(bench, [session(70, [8, 8, 8, 8]), session(70, [10, 10, 9, 8], daysAgo: 7)])
        #expect(approx(result.bestEstimatedOneRM, 93.33))
    }

    @Test("Load kind from equipment", arguments: [
        ([Equipment.barbell], ProgressionType.doubleProgression, "barbell"),
        ([.ezBar, .machines], .doubleProgression, "barbell"),
        ([.dumbbells, .adjustableBench], .doubleProgression, "dumbbell"),
        ([.cables], .doubleProgression, "machine"),
        ([.pullUpBar], .bodyweight, "bodyweight"),
        ([.bodyweight], .timed, "timed")
    ])
    func loadKind(equipment: [Equipment], progression: ProgressionType, expected: String) {
        let kind = LoadKind.from(equipment: equipment, progression: progression, settings: settings)
        let name = switch kind {
        case .barbell: "barbell"
        case .dumbbell: "dumbbell"
        case .machine: "machine"
        case .bodyweight: "bodyweight"
        case .timed: "timed"
        }
        #expect(name == expected)
    }
}

@Suite("Calibration, deload, wellness")
struct CalibrationDeloadWellnessTests {
    let settings = LoadSettings()
    let bench = ExercisePlan(sets: 4, repMin: 6, repMax: 8, targetRIR: 2, load: .barbell)

    @Test func calibrationAfterLightSet() {
        // 40 × 12 with 3 in reserve ≈ 15RM → 1RM 60 → 6 reps @ 2 RIR = 78.6 % = 47.2 → 45
        let next = Calibration.nextWeight(after: PerformedSet(weight: 40, reps: 12, rir: 3), plan: bench, settings: settings)
        #expect(next == 45)
        // Never lower than the weight just lifted
        #expect(Calibration.nextWeight(after: PerformedSet(weight: 60, reps: 3, rir: 0), plan: bench, settings: settings) == 60)
    }

    @Test func calibrationFirstSet() {
        #expect(Calibration.firstSetWeight(plan: bench, settings: settings) == 20)
        let dumbbells = ExercisePlan(sets: 3, repMin: 8, repMax: 10, load: .dumbbell(stepKg: 2, maxKg: 40))
        #expect(Calibration.firstSetWeight(plan: dumbbells, settings: settings) == 4)
    }

    @Test func deloadTiming() {
        let now = day(0)
        #expect(DeloadAdvisor.reason(blockStart: day(-56, from: now), now: now, stalledCompoundLifts: 0, calendar: utc) == .scheduled(weeks: 8))
        #expect(DeloadAdvisor.reason(blockStart: day(-21, from: now), now: now, stalledCompoundLifts: 2, calendar: utc) == .stalls(count: 2))
        #expect(DeloadAdvisor.reason(blockStart: day(-21, from: now), now: now, stalledCompoundLifts: 1, calendar: utc) == nil)
        #expect(DeloadAdvisor.reason(blockStart: nil, now: now, stalledCompoundLifts: 0, calendar: utc) == nil)
        #expect(DeloadAdvisor.deloadSets(4) == 2)
        #expect(DeloadAdvisor.deloadSets(3) == 1)
        #expect(DeloadAdvisor.deloadSets(1) == 1)
    }

    @Test func wellness() {
        #expect(WellnessAdvisor.suggestion(sleep: 2, energy: 2, soreness: 3) == .reduce)
        #expect(WellnessAdvisor.suggestion(sleep: 4, energy: 4, soreness: 4) == .none)
        #expect(WellnessAdvisor.suggestion(sleep: 5, energy: 5, soreness: 1) == .reduce)
        #expect(WellnessAdvisor.reducedWeight(100, step: 2.5) == 95)
        #expect(WellnessAdvisor.reducedWeight(72.5, step: 2.5) == 70) // 68.9 → 70
    }
}

@Suite("Records, rest timer, stats")
struct WorkoutMathTests {
    @Test func firstSessionIsNotARecordButSetsBaseline() {
        var bests = ExerciseBests()
        #expect(bests.register(PerformedSet(weight: 60, reps: 10)).isEmpty)
        #expect(bests.maxWeight == 60)
        #expect(bests.repMax[10] == 60)
    }

    @Test func heavierSetBreaksRecords() {
        var bests = ExerciseBests(sets: [PerformedSet(weight: 60, reps: 10), PerformedSet(weight: 70, reps: 5)])
        let hits = bests.register(PerformedSet(weight: 72.5, reps: 5))
        let kinds = Set(hits.map(\.kind))
        #expect(kinds.contains(.maxWeight))
        #expect(kinds.contains(.estimatedOneRM))
        #expect(hits.contains { $0.kind == .repMax && $0.repTarget == 5 })
        #expect(hits.contains { $0.kind == .repMax && $0.repTarget == 3 })
        #expect(!hits.contains { $0.kind == .repMax && $0.repTarget == 8 })
        #expect(!kinds.contains(.setVolume)) // 362.5 < 600
    }

    @Test func moreRepsAtSameWeight() {
        var bests = ExerciseBests(sets: [PerformedSet(weight: 60, reps: 8)])
        let hits = bests.register(PerformedSet(weight: 60, reps: 10))
        #expect(hits.contains { $0.kind == .repMax && $0.repTarget == 10 })
        #expect(hits.contains { $0.kind == .estimatedOneRM })
        #expect(hits.contains { $0.kind == .setVolume })
        #expect(!hits.contains { $0.kind == .maxWeight })
    }

    @Test func invalidSetsIgnored() {
        var bests = ExerciseBests(sets: [PerformedSet(weight: 60, reps: 8)])
        #expect(bests.register(PerformedSet(weight: 80, reps: 0)).isEmpty)
        #expect(bests.maxWeight == 60)
    }

    @Test func restTimer() {
        let start = day(0)
        var timer = RestTimer(start: start, seconds: 90)
        #expect(timer.remaining(at: start.addingTimeInterval(30)) == 60)
        #expect(approx(timer.progress(at: start.addingTimeInterval(45)), 0.5))
        timer.add(seconds: 30, now: start.addingTimeInterval(30))
        #expect(timer.remaining(at: start.addingTimeInterval(30)) == 90)
        #expect(!timer.isFinished(at: start.addingTimeInterval(100)))
        #expect(timer.isFinished(at: start.addingTimeInterval(121)))
        // +30 after the timer ended restarts from now
        timer.add(seconds: 30, now: start.addingTimeInterval(200))
        #expect(timer.remaining(at: start.addingTimeInterval(200)) == 30)
        #expect(RestTimer.format(65) == "1:05")
        #expect(RestTimer.format(0) == "0:00")
        #expect(RestTimer(start: start, seconds: 0).progress(at: start) == 1)
    }

    @Test func stats() throws {
        let stats = WorkoutStats(durationSeconds: 3900, sets: [
            [Volume.SetSample(weight: 20, reps: 10, isWarmup: true), Volume.SetSample(weight: 70, reps: 8), Volume.SetSample(weight: 70, reps: 8)],
            [Volume.SetSample(weight: 30, reps: 10)],
            [Volume.SetSample(weight: 20, reps: 10, isWarmup: true)]
        ])
        #expect(stats.tonnage == 1420)
        #expect(stats.workingSets == 3)
        #expect(stats.exercises == 2)
        #expect(stats.hoursMinutes == (1, 5))
        let previous = WorkoutStats(durationSeconds: 3600, sets: [[Volume.SetSample(weight: 71, reps: 20)]])
        #expect(approx(try #require(stats.tonnageChangePercent(vs: previous)), 0))
        #expect(stats.tonnageChangePercent(vs: nil) == nil)
    }
}
