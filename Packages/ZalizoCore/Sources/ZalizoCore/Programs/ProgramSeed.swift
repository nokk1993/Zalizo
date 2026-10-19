import Foundation

/// Built-in program as stored in `Resources/Seed/programs.json`.
public struct ProgramSeed: Codable, Equatable, Sendable {
    public struct PlannedExerciseSeed: Codable, Equatable, Sendable {
        public var slug: String
        public var sets: Int
        public var repMin: Int
        public var repMax: Int
        public var restSeconds: Int
        public var targetRIR: Int
        public var note: String
    }

    public struct DaySeed: Codable, Equatable, Sendable {
        public var name: String
        public var focus: String
        public var exercises: [PlannedExerciseSeed]
    }

    public var slug: String
    public var name: String
    public var summary: String
    public var audience: String
    public var recommendedWeeks: Int
    public var sessionsPerWeek: Int
    public var progressionNotes: String
    public var days: [DaySeed]
}

public struct ProgramSeedFile: Codable, Equatable, Sendable {
    public var version: Int
    public var programs: [ProgramSeed]

    public static func decode(_ data: Data) throws -> ProgramSeedFile {
        try JSONDecoder().decode(ProgramSeedFile.self, from: data)
    }
}

/// What the logic needs to know about an exercise (built from the seed or from the database).
public struct ExerciseInfo: Equatable, Sendable {
    public var slug: String
    public var primary: [MuscleGroup]
    public var secondary: [MuscleGroup]
    public var equipment: [Equipment]
    public var riskAreas: [InjuryArea]
    public var alternatives: [String]
    public var mechanic: ExerciseMechanic
    public var region: BodyRegion
    public var progression: ProgressionType

    public init(
        slug: String, primary: [MuscleGroup], secondary: [MuscleGroup], equipment: [Equipment],
        riskAreas: [InjuryArea], alternatives: [String], mechanic: ExerciseMechanic = .compound,
        region: BodyRegion = .upper, progression: ProgressionType = .doubleProgression
    ) {
        self.slug = slug
        self.primary = primary
        self.secondary = secondary
        self.equipment = equipment
        self.riskAreas = riskAreas
        self.alternatives = alternatives
        self.mechanic = mechanic
        self.region = region
        self.progression = progression
    }

    public init(_ seed: ExerciseSeed) {
        self.init(
            slug: seed.slug, primary: seed.primaryMuscles, secondary: seed.secondaryMuscles, equipment: seed.equipment,
            riskAreas: seed.riskAreas, alternatives: seed.alternatives, mechanic: seed.mechanic,
            region: seed.region, progression: seed.progression
        )
    }
}

public enum ProgramVolume {
    /// Major groups that must land in the 10–20 weekly sets corridor.
    public static let majorGroups: [MuscleGroup] = [.chest, .back, .shoulders, .quads, .hamstrings, .glutes, .biceps, .triceps]

    public struct DayExercise: Sendable {
        public let slug: String
        public let sets: Int

        public init(slug: String, sets: Int) {
            self.slug = slug
            self.sets = sets
        }
    }

    /// Weekly hard sets per muscle when the program days are rotated `sessionsPerWeek` times a week
    /// (e.g. Full Body A/B at 3×/week → each day 1.5× per week).
    public static func weeklySets(days: [[DayExercise]], sessionsPerWeek: Int, catalog: [String: ExerciseInfo]) -> [MuscleGroup: Double] {
        guard !days.isEmpty else { return [:] }
        let factor = Double(sessionsPerWeek) / Double(days.count)
        let items = days.flatMap { $0 }.compactMap { item -> Volume.ExerciseSets? in
            guard let info = catalog[item.slug] else { return nil }
            return Volume.ExerciseSets(primary: info.primary, secondary: info.secondary, workingSets: item.sets)
        }
        return Volume.setsPerMuscle(items).mapValues { $0 * factor }
    }
}

/// Picks a safe, available exercise when the planned one needs missing equipment or loads an injured area.
public enum ExerciseSubstitution {
    public enum Reason: Equatable, Sendable {
        case missingEquipment([Equipment])
        case injuryRisk([InjuryArea])
    }

    public struct Resolution: Equatable, Sendable {
        public let slug: String
        /// nil → the planned exercise is used as is.
        public let replacedBecause: Reason?
        /// True when no suitable alternative was found and the original stays despite the problem.
        public let isFallback: Bool
    }

    /// Equipment that is assumed to be present in any gym.
    static let alwaysAvailable: Set<Equipment> = [.bodyweight]

    public static func problem(for info: ExerciseInfo, equipment: Set<Equipment>, limitations: Set<InjuryArea>) -> Reason? {
        let available = equipment.union(alwaysAvailable)
        let missing = info.equipment.filter { !available.contains($0) }
        if !missing.isEmpty { return .missingEquipment(missing) }
        let risky = info.riskAreas.filter(limitations.contains)
        if !risky.isEmpty { return .injuryRisk(risky) }
        return nil
    }

    /// Breadth-first search through alternatives (and their alternatives) for the first exercise without problems.
    public static func resolve(slug: String, catalog: [String: ExerciseInfo], equipment: Set<Equipment>, limitations: Set<InjuryArea>) -> Resolution {
        guard let info = catalog[slug] else { return Resolution(slug: slug, replacedBecause: nil, isFallback: false) }
        guard let reason = problem(for: info, equipment: equipment, limitations: limitations) else {
            return Resolution(slug: slug, replacedBecause: nil, isFallback: false)
        }
        var queue = info.alternatives
        var visited: Set<String> = [slug]
        var depth = 0
        while !queue.isEmpty, depth < 3 {
            var next: [String] = []
            for candidate in queue where !visited.contains(candidate) {
                visited.insert(candidate)
                guard let candidateInfo = catalog[candidate] else { continue }
                // Keep the same main muscle so the program stays balanced.
                let sameTarget = !Set(candidateInfo.primary).isDisjoint(with: info.primary)
                if sameTarget, problem(for: candidateInfo, equipment: equipment, limitations: limitations) == nil {
                    return Resolution(slug: candidate, replacedBecause: reason, isFallback: false)
                }
                next.append(contentsOf: candidateInfo.alternatives)
            }
            queue = next
            depth += 1
        }
        return Resolution(slug: slug, replacedBecause: reason, isFallback: true)
    }
}
