import Foundation

/// One completed working set.
public struct PerformedSet: Equatable, Sendable {
    public var weight: Double
    public var reps: Int
    public var rir: Int?

    public init(weight: Double, reps: Int, rir: Int? = nil) {
        self.weight = weight
        self.reps = reps
        self.rir = rir
    }
}

/// An exercise as performed in one past workout (working sets only).
public struct ExerciseHistoryEntry: Equatable, Sendable {
    public var date: Date
    public var sets: [PerformedSet]
    public var wasDeload: Bool

    public init(date: Date, sets: [PerformedSet], wasDeload: Bool = false) {
        self.date = date
        self.sets = sets
        self.wasDeload = wasDeload
    }

    /// Heaviest working weight of the session.
    public var topWeight: Double { sets.map(\.weight).max() ?? 0 }
    /// Sets done with the top weight (small tolerance for rounding).
    public var topSets: [PerformedSet] { sets.filter { $0.weight >= topWeight - 0.01 } }

    public func bestEstimatedOneRM(formula: OneRMFormula = .epley) -> Double {
        sets.map { OneRM.estimate(weight: $0.weight, reps: $0.reps, formula: formula).value }.max() ?? 0
    }
}

/// What kind of load the exercise uses - decides the weight increment.
public enum LoadKind: Equatable, Sendable {
    case barbell
    case dumbbell(stepKg: Double, maxKg: Double)
    case machine(stepKg: Double)
    /// Extra weight on a belt (0 = bodyweight only).
    case bodyweight
    /// Holds measured in seconds (plank). `reps` = seconds.
    case timed

    public static func from(equipment: [Equipment], progression: ProgressionType, settings: LoadSettings) -> LoadKind {
        if progression == .timed { return .timed }
        if progression == .bodyweight { return .bodyweight }
        if equipment.contains(.barbell) || equipment.contains(.ezBar) { return .barbell }
        if equipment.contains(.dumbbells) { return .dumbbell(stepKg: settings.dumbbellStepKg, maxKg: settings.dumbbellMaxKg) }
        if equipment.contains(.machines) || equipment.contains(.cables) { return .machine(stepKg: settings.machineStepKg) }
        return .bodyweight
    }
}

public struct LoadSettings: Equatable, Sendable {
    public var barbellStepKg: Double
    public var dumbbellStepKg: Double
    public var dumbbellMaxKg: Double
    public var machineStepKg: Double
    public var barWeightKg: Double

    public init(
        barbellStepKg: Double = Defaults.barbellStepKg, dumbbellStepKg: Double = Defaults.dumbbellStepKg,
        dumbbellMaxKg: Double = Defaults.dumbbellMaxKg, machineStepKg: Double = Defaults.machineStepKg,
        barWeightKg: Double = Defaults.barWeightKg
    ) {
        self.barbellStepKg = barbellStepKg
        self.dumbbellStepKg = dumbbellStepKg
        self.dumbbellMaxKg = dumbbellMaxKg
        self.machineStepKg = machineStepKg
        self.barWeightKg = barWeightKg
    }
}

/// Plan for one exercise in a workout.
public struct ExercisePlan: Equatable, Sendable {
    public var sets: Int
    public var repMin: Int
    public var repMax: Int
    public var targetRIR: Int
    public var load: LoadKind
    public var region: BodyRegion
    public var mechanic: ExerciseMechanic
    /// Overrides the automatic increment.
    public var incrementOverrideKg: Double?

    public init(
        sets: Int, repMin: Int, repMax: Int, targetRIR: Int = 2, load: LoadKind,
        region: BodyRegion = .upper, mechanic: ExerciseMechanic = .compound, incrementOverrideKg: Double? = nil
    ) {
        self.sets = sets
        self.repMin = repMin
        self.repMax = repMax
        self.targetRIR = targetRIR
        self.load = load
        self.region = region
        self.mechanic = mechanic
        self.incrementOverrideKg = incrementOverrideKg
    }
}

/// Today's target for one exercise.
public struct Prescription: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// No history and no baseline: start light and calibrate after the first set.
        case calibrate
        /// No history, weight derived from the onboarding 1RM baseline.
        case fromBaseline
        /// Top of the rep range reached in all sets → heavier.
        case increaseWeight
        /// Within the range → same weight, +1 rep in the weakest set.
        case addReps
        /// Missed the bottom of the range once → same weight, aim for the minimum.
        case repeatWeight
        /// Missed the bottom of the range two sessions in a row → −10 % or swap the exercise.
        case stall
        /// Timed hold progression.
        case extendHold
    }

    public var kind: Kind
    /// Working weight (0 for bodyweight-only / timed / unknown).
    public var weight: Double
    /// Target reps (or seconds) per working set.
    public var reps: [Int]
    /// Change vs. the last session's top weight (positive = heavier).
    public var weightChange: Double
    /// Most recent session for "минулого разу: 70 кг × 10, 10, 9, 8".
    public var last: ExerciseHistoryEntry?
    /// Best estimated 1RM across history - "побити рекорд (зараз 93 кг)".
    public var bestEstimatedOneRM: Double
}

/// Double progression engine (see knowledge base: "Як працює подвійна прогресія").
public enum ProgressionEngine {
    /// Percentage drop suggested after a stall.
    public static let stallReduction = 0.10

    /// Weight increment for the next jump.
    /// Upper body +2.5 kg, lower body +5 kg, dumbbells → next dumbbell, isolation +1-2.5 kg.
    public static func increment(for plan: ExercisePlan, settings: LoadSettings, from weight: Double) -> Double {
        if let override = plan.incrementOverrideKg { return override }
        switch plan.load {
        case .barbell:
            if plan.mechanic == .isolation { return settings.barbellStepKg }
            return plan.region == .lower ? max(5, settings.barbellStepKg) : settings.barbellStepKg
        case .dumbbell(let step, let maxKg):
            guard let next = WeightRounding.nextDumbbell(after: weight, step: step, maxKg: maxKg) else { return 0 }
            return next - weight
        case .machine(let step):
            return plan.mechanic == .isolation ? min(step, 2.5) : step
        case .bodyweight:
            return 2.5
        case .timed:
            return 0
        }
    }

    public static func roundingStep(for plan: ExercisePlan, settings: LoadSettings) -> Double {
        switch plan.load {
        case .barbell: settings.barbellStepKg
        case .dumbbell(let step, _): step
        case .machine(let step): plan.mechanic == .isolation ? min(step, 2.5) : step
        case .bodyweight: 2.5
        case .timed: 1
        }
    }

    /// - Parameters:
    ///   - history: past sessions of this exercise, newest first (deload sessions are skipped for decisions).
    ///   - baselineOneRM: estimate from onboarding ("жим 70 × 10"), used only without history.
    public static func prescribe(
        plan: ExercisePlan, history: [ExerciseHistoryEntry], baselineOneRM: Double?,
        settings: LoadSettings, formula: OneRMFormula = .epley
    ) -> Prescription {
        let relevant = history.filter { !$0.wasDeload && !$0.sets.isEmpty }
        let best = history.map { $0.bestEstimatedOneRM(formula: formula) }.max() ?? baselineOneRM ?? 0
        let setCount = max(1, plan.sets)

        guard let last = relevant.first else {
            if let baselineOneRM, baselineOneRM > 0, plan.load != .timed {
                let weight = startingWeight(oneRM: baselineOneRM, plan: plan, settings: settings)
                return Prescription(kind: .fromBaseline, weight: weight, reps: Array(repeating: plan.repMin, count: setCount),
                                    weightChange: 0, last: nil, bestEstimatedOneRM: best)
            }
            return Prescription(kind: .calibrate, weight: 0, reps: Array(repeating: plan.repMin, count: setCount),
                                weightChange: 0, last: history.first, bestEstimatedOneRM: best)
        }

        if plan.load == .timed {
            return timedPrescription(plan: plan, last: last, best: best)
        }

        let weight = last.topWeight
        let topSets = last.topSets
        let reps = topSets.map(\.reps)
        let completedAllSets = topSets.count >= setCount

        // 1. Top of the range in every planned set → add weight, restart at the bottom of the range.
        if completedAllSets, reps.allSatisfy({ $0 >= plan.repMax }) {
            let step = increment(for: plan, settings: settings, from: weight)
            if step > 0 {
                return Prescription(kind: .increaseWeight, weight: weight + step, reps: Array(repeating: plan.repMin, count: setCount),
                                    weightChange: step, last: last, bestEstimatedOneRM: best)
            }
            // Heaviest dumbbell reached: keep adding reps beyond the range.
            return Prescription(kind: .addReps, weight: weight, reps: nextReps(from: reps, setCount: setCount, cap: plan.repMax + 5),
                                weightChange: 0, last: last, bestEstimatedOneRM: best)
        }

        let missedBottom = reps.contains { $0 < plan.repMin } || topSets.count < setCount
        if !missedBottom {
            // 2. Inside the range → same weight, +1 rep in the weakest set.
            return Prescription(kind: .addReps, weight: weight, reps: nextReps(from: reps, setCount: setCount, cap: plan.repMax),
                                weightChange: 0, last: last, bestEstimatedOneRM: best)
        }

        // 3. Below the range: a stall if the previous session also missed at the same or heavier weight.
        if relevant.count >= 2 {
            let previous = relevant[1]
            let previousMissed = previous.topWeight >= weight - 0.01
                && (previous.topSets.contains { $0.reps < plan.repMin } || previous.topSets.count < setCount)
            if previousMissed {
                let step = roundingStep(for: plan, settings: settings)
                let reduced = WeightRounding.round(weight * (1 - stallReduction), step: step, mode: .nearest)
                return Prescription(kind: .stall, weight: reduced, reps: Array(repeating: plan.repMin, count: setCount),
                                    weightChange: reduced - weight, last: last, bestEstimatedOneRM: best)
            }
        }
        return Prescription(kind: .repeatWeight, weight: weight, reps: Array(repeating: plan.repMin, count: setCount),
                            weightChange: 0, last: last, bestEstimatedOneRM: best)
    }

    /// +1 rep on the weakest set, other sets repeat what was done (never below the previous result).
    static func nextReps(from reps: [Int], setCount: Int, cap: Int) -> [Int] {
        var targets = Array(reps.prefix(setCount))
        while targets.count < setCount { targets.append(targets.min() ?? 0) }
        if let index = targets.indices.min(by: { targets[$0] < targets[$1] }) {
            targets[index] = min(targets[index] + 1, cap)
        }
        return targets
    }

    /// Working weight for the first session from a baseline 1RM (reps at the bottom of the range, planned RIR).
    public static func startingWeight(oneRM: Double, plan: ExercisePlan, settings: LoadSettings) -> Double {
        let step = roundingStep(for: plan, settings: settings)
        let weight = OneRM.workingWeight(oneRM: oneRM, reps: plan.repMin, rir: plan.targetRIR, step: step)
        if case .barbell = plan.load { return max(weight, settings.barWeightKg) }
        return weight
    }

    private static func timedPrescription(plan: ExercisePlan, last: ExerciseHistoryEntry, best: Double) -> Prescription {
        let setCount = max(1, plan.sets)
        let holds = last.sets.map(\.reps)
        if holds.count >= setCount, holds.allSatisfy({ $0 >= plan.repMax }) {
            return Prescription(kind: .extendHold, weight: last.topWeight, reps: Array(repeating: plan.repMax + 10, count: setCount),
                                weightChange: 0, last: last, bestEstimatedOneRM: best)
        }
        let targets = holds.isEmpty ? Array(repeating: plan.repMin, count: setCount)
            : nextReps(from: holds, setCount: setCount, cap: plan.repMax).map { max($0, plan.repMin) }
        return Prescription(kind: .extendHold, weight: last.topWeight, reps: targets, weightChange: 0, last: last, bestEstimatedOneRM: best)
    }
}

/// First-workout calibration: after a light set the user reports reps and RIR;
/// the estimated 1RM gives the weight for the remaining sets.
public enum Calibration {
    /// Suggested very light first set when nothing is known (empty bar, lightest dumbbells, light stack).
    public static func firstSetWeight(plan: ExercisePlan, settings: LoadSettings) -> Double {
        switch plan.load {
        case .barbell: settings.barWeightKg
        case .dumbbell(let step, _): max(step * 2, 4)
        case .machine(let step): step * 2
        case .bodyweight, .timed: 0
        }
    }

    public static func nextWeight(after set: PerformedSet, plan: ExercisePlan, settings: LoadSettings, formula: OneRMFormula = .epley) -> Double {
        let estimate = OneRM.estimate(weight: set.weight, reps: set.reps, rir: set.rir ?? 0, formula: formula).value
        guard estimate > 0 else { return set.weight }
        let step = ProgressionEngine.roundingStep(for: plan, settings: settings)
        let target = OneRM.workingWeight(oneRM: estimate, reps: plan.repMin, rir: plan.targetRIR, step: step)
        // Never suggest less than what was just lifted with reps to spare.
        return max(target, set.weight)
    }
}

/// When to propose a lighter week.
public enum DeloadAdvisor {
    public static let weeksBetweenDeloads = 7

    public enum Reason: Equatable, Sendable {
        case scheduled(weeks: Int)
        case stalls(count: Int)
    }

    public static func reason(blockStart: Date?, now: Date = .now, stalledCompoundLifts: Int, calendar: Calendar = .current) -> Reason? {
        if stalledCompoundLifts >= 2 { return .stalls(count: stalledCompoundLifts) }
        guard let blockStart else { return nil }
        let weeks = (calendar.dateComponents([.day], from: blockStart, to: now).day ?? 0) / 7
        return weeks >= weeksBetweenDeloads ? .scheduled(weeks: weeks) : nil
    }

    /// −40…50 % of the volume at the same weight: roughly half the sets, at least one.
    public static func deloadSets(_ sets: Int) -> Int {
        max(1, Int((Double(sets) * 0.5).rounded(.down)))
    }
}

/// "Як ти сьогодні?" - 1 = погано … 5 = відмінно for each answer.
public enum WellnessAdvisor {
    public enum Suggestion: Equatable, Sendable {
        case none
        /// Offer: −1 set per exercise or −5 % weight. Never applied without confirmation.
        case reduce
    }

    public static func suggestion(sleep: Int, energy: Int, soreness: Int) -> Suggestion {
        let average = Double(sleep + energy + soreness) / 3
        return average <= 2.5 || min(sleep, energy, soreness) == 1 ? .reduce : .none
    }

    public static let weightReduction = 0.05

    public static func reducedWeight(_ weight: Double, step: Double) -> Double {
        WeightRounding.round(weight * (1 - weightReduction), step: step, mode: .nearest)
    }
}
