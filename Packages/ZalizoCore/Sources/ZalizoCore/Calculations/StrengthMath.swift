import Foundation

/// One-rep-max estimation and load prescription.
public enum OneRM {
    /// Above this rep count the estimate becomes unreliable (both formulas drift).
    public static let reliableRepLimit = 12

    public struct Estimate: Equatable, Sendable {
        public let value: Double
        public let isReliable: Bool
    }

    /// Epley (1985): w · (1 + reps / 30).
    public static func epley(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// Brzycki (1993): w · 36 / (37 − reps). Undefined for reps ≥ 37 → falls back to Epley.
    public static func brzycki(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        guard reps < 37 else { return epley(weight: weight, reps: reps) }
        return weight * 36 / Double(37 - reps)
    }

    /// - Parameter rir: reps in reserve; a set of 8 with 2 RIR is treated as a 10-rep max.
    public static func estimate(weight: Double, reps: Int, rir: Int = 0, formula: OneRMFormula = .epley) -> Estimate {
        let effectiveReps = reps + max(0, rir)
        let value = switch formula {
        case .epley: epley(weight: weight, reps: effectiveReps)
        case .brzycki: brzycki(weight: weight, reps: effectiveReps)
        }
        return Estimate(value: value, isReliable: effectiveReps <= reliableRepLimit)
    }

    /// %1RM for a set taken to failure (RPE 10), index = reps − 1.
    /// Values from the RTS / Tuchscherer RPE chart; RIR shifts the row by one rep per RIR
    /// (e.g. 8 reps @ 2 RIR ≈ 10RM ≈ 73.9 %).
    static let rpe10Percent: [Double] = [
        100, 95.5, 92.2, 89.2, 86.3, 83.7, 81.1, 78.6, 76.2, 73.9, 70.7, 68.0, 65.3, 62.6, 59.9
    ]

    /// Fraction of 1RM (0…1) that allows exactly `reps` with `rir` reps left in the tank.
    public static func percentOfOneRM(reps: Int, rir: Int = 0) -> Double {
        let effective = max(1, reps + max(0, rir))
        if effective <= rpe10Percent.count {
            return rpe10Percent[effective - 1] / 100
        }
        // Beyond the chart: inverse Epley.
        return 1 / (1 + Double(effective) / 30)
    }

    /// Working weight for a rep target at a given RIR, rounded to the equipment step.
    public static func workingWeight(oneRM: Double, reps: Int, rir: Int, step: Double) -> Double {
        WeightRounding.round(oneRM * percentOfOneRM(reps: reps, rir: rir), step: step, mode: .down)
    }

    /// 1RM ÷ body weight (bench / squat / deadlift).
    public static func relativeStrength(oneRM: Double, bodyWeightKg: Double) -> Double {
        bodyWeightKg > 0 ? oneRM / bodyWeightKg : 0
    }
}

public enum WeightRounding {
    public enum Mode: Sendable {
        case nearest
        case down
        case up
    }

    /// Rounds to a multiple of `step` (2.5 kg barbell, 1-2 kg dumbbells, machine stack…).
    public static func round(_ weight: Double, step: Double, mode: Mode = .nearest) -> Double {
        guard step > 0 else { return weight }
        let units = weight / step
        // Small epsilon so 72.4999999 does not round down due to floating point noise.
        let rounded: Double = switch mode {
        case .nearest: units.rounded()
        case .down: (units + 1e-9).rounded(.down)
        case .up: (units - 1e-9).rounded(.up)
        }
        return max(0, rounded * step)
    }

    /// Next heavier dumbbell available (fixed pairs every `step`, up to `maxKg`). nil if already at max.
    public static func nextDumbbell(after weight: Double, step: Double, maxKg: Double) -> Double? {
        let next = round(weight, step: step, mode: .down) + step
        return next <= maxKg + 1e-9 ? next : nil
    }
}

/// Which plates to load on each side of the bar.
public enum PlateCalculator {
    public struct Result: Equatable, Sendable {
        /// Heaviest first, per side.
        public let perSide: [Double]
        public let achievedTotal: Double
        /// Target − achieved (≥ 0) when the exact weight is impossible with the available plates.
        public let remainder: Double

        public var isExact: Bool { remainder < 0.001 }
    }

    /// - Parameters:
    ///   - plates: available plate weights; `pairs` limits how many pairs of each exist (nil = unlimited).
    public static func load(target: Double, barWeight: Double, plates: [Double], pairs: [Double: Int]? = nil) -> Result {
        guard target > barWeight else {
            return Result(perSide: [], achievedTotal: barWeight, remainder: max(0, target - barWeight))
        }
        var remainingPerSide = (target - barWeight) / 2
        var perSide: [Double] = []
        for plate in plates.filter({ $0 > 0 }).sorted(by: >) {
            var available = pairs?[plate] ?? Int.max
            while remainingPerSide + 1e-9 >= plate, available > 0 {
                perSide.append(plate)
                remainingPerSide -= plate
                available -= 1
            }
        }
        let achieved = barWeight + 2 * perSide.reduce(0, +)
        return Result(perSide: perSide, achievedTotal: achieved, remainder: max(0, target - achieved))
    }
}

public struct WarmupSet: Equatable, Sendable {
    public let weight: Double
    public let reps: Int
}

/// Warm-up ramp for compound lifts: bar × 10, 40 % × 8, 60 % × 5, 80 % × 3.
public enum WarmupGenerator {
    static let ramp: [(fraction: Double, reps: Int)] = [(0.4, 8), (0.6, 5), (0.8, 3)]

    /// - Parameters:
    ///   - barWeight: empty bar (barbell lifts) - nil for dumbbells/machines.
    public static func sets(workingWeight: Double, mechanic: ExerciseMechanic, barWeight: Double?, step: Double) -> [WarmupSet] {
        guard mechanic == .compound, workingWeight > 0 else { return [] }
        var sets: [WarmupSet] = []
        let floor = barWeight ?? 0
        if let barWeight, workingWeight > barWeight {
            sets.append(WarmupSet(weight: barWeight, reps: 10))
        }
        for item in ramp {
            let weight = WeightRounding.round(workingWeight * item.fraction, step: step, mode: .nearest)
            let previous = sets.last?.weight ?? 0
            // Skip ramp steps that are not heavier than the bar/previous set or that reach the working weight.
            guard weight > floor, weight > previous, weight < workingWeight else { continue }
            sets.append(WarmupSet(weight: weight, reps: item.reps))
        }
        return sets
    }
}

/// Training volume.
public enum Volume {
    public struct SetSample: Equatable, Sendable {
        public let weight: Double
        public let reps: Int
        public let isWarmup: Bool

        public init(weight: Double, reps: Int, isWarmup: Bool = false) {
            self.weight = weight
            self.reps = reps
            self.isWarmup = isWarmup
        }
    }

    /// Tonnage = Σ weight × reps over working sets.
    public static func tonnage(_ sets: [SetSample]) -> Double {
        sets.filter { !$0.isWarmup }.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    public struct ExerciseSets: Sendable {
        public let primary: [MuscleGroup]
        public let secondary: [MuscleGroup]
        public let workingSets: Int

        public init(primary: [MuscleGroup], secondary: [MuscleGroup], workingSets: Int) {
            self.primary = primary
            self.secondary = secondary
            self.workingSets = workingSets
        }
    }

    /// Weekly hard sets per muscle group. A set counts fully for primary muscles and as ½ for secondary ones
    /// (fractional counting, Pelland et al., 2024).
    public static func setsPerMuscle(_ items: [ExerciseSets]) -> [MuscleGroup: Double] {
        var totals: [MuscleGroup: Double] = [:]
        for item in items {
            for muscle in Set(item.primary) {
                totals[muscle, default: 0] += Double(item.workingSets)
            }
            for muscle in Set(item.secondary).subtracting(item.primary) {
                totals[muscle, default: 0] += Double(item.workingSets) * 0.5
            }
        }
        return totals
    }

    public enum Zone: Equatable, Sendable {
        case low, optimal, high
    }

    /// Hypertrophy guideline: 10-20 hard sets per muscle per week.
    public static func zone(weeklySets: Double) -> Zone {
        if weeklySets < 10 { return .low }
        if weeklySets > 20 { return .high }
        return .optimal
    }
}
