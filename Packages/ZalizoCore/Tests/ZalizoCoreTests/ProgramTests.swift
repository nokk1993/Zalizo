import Foundation
import Testing
@testable import ZalizoCore

extension SeedFiles {
    static func programs() throws -> ProgramSeedFile {
        try ProgramSeedFile.decode(Data(contentsOf: url("Zalizo/Resources/Seed/programs.json")))
    }

    static func catalog() throws -> [String: ExerciseInfo] {
        Dictionary(uniqueKeysWithValues: try exercises().exercises.map { ($0.slug, ExerciseInfo($0)) })
    }
}

@Suite("Program seed")
struct ProgramSeedTests {
    @Test func allBuiltInProgramsExist() throws {
        let slugs = Set(try SeedFiles.programs().programs.map(\.slug))
        #expect(slugs == [ProgramCatalog.massSplit3, ProgramCatalog.fullBody3, ProgramCatalog.upperLower4,
                          ProgramCatalog.pushPullLegs3, ProgramCatalog.pushPullLegs6])
    }

    @Test func exercisesResolveAndPrescriptionsAreSane() throws {
        let catalog = try SeedFiles.catalog()
        for program in try SeedFiles.programs().programs {
            #expect(!program.days.isEmpty)
            #expect(program.sessionsPerWeek >= program.days.count || program.days.count == 2, "\(program.slug)")
            for day in program.days {
                #expect(!day.exercises.isEmpty)
                for item in day.exercises {
                    #expect(catalog[item.slug] != nil, "\(program.slug): \(item.slug)")
                    #expect(item.repMin <= item.repMax)
                    #expect((1...6).contains(item.sets))
                    #expect((30...300).contains(item.restSeconds))
                    #expect((0...4).contains(item.targetRIR))
                }
            }
        }
    }

    @Test func defaultProgramMatchesSpec() throws {
        let program = try #require(try SeedFiles.programs().programs.first { $0.slug == ProgramCatalog.massSplit3 })
        #expect(program.days.map { $0.exercises.count } == [7, 8, 8])
        let first = try #require(program.days.first?.exercises.first)
        #expect(first.slug == "barbell-bench-press")
        #expect(first.sets == 4 && first.repMin == 6 && first.repMax == 8)
    }

    /// Weekly volume of major groups must be 10-20 hard sets.
    /// Known exception from the owner's spec: the 3-day split trains legs once a week (quads ≈ 7 sets).
    @Test func weeklyVolumeInCorridor() throws {
        let catalog = try SeedFiles.catalog()
        for program in try SeedFiles.programs().programs {
            let days = program.days.map { $0.exercises.map { ProgramVolume.DayExercise(slug: $0.slug, sets: $0.sets) } }
            let weekly = ProgramVolume.weeklySets(days: days, sessionsPerWeek: program.sessionsPerWeek, catalog: catalog)
            for muscle in ProgramVolume.majorGroups {
                if program.slug == ProgramCatalog.massSplit3 && muscle == .quads { continue }
                let sets = weekly[muscle] ?? 0
                #expect((10...20).contains(sets), "\(program.slug) \(muscle): \(sets)")
            }
        }
    }

    @Test func rotationFactor() {
        let catalog = ["a": ExerciseInfo(slug: "a", primary: [.chest], secondary: [], equipment: [], riskAreas: [], alternatives: [])]
        let days = [[ProgramVolume.DayExercise(slug: "a", sets: 4)], [ProgramVolume.DayExercise(slug: "a", sets: 2)]]
        // A/B rotated three times a week → (4 + 2) × 1.5
        #expect(ProgramVolume.weeklySets(days: days, sessionsPerWeek: 3, catalog: catalog)[.chest] == 9)
        #expect(ProgramVolume.weeklySets(days: [], sessionsPerWeek: 3, catalog: catalog).isEmpty)
    }
}

@Suite("Exercise substitution")
struct SubstitutionTests {
    let gym = Set(Equipment.allCases)

    @Test func availableExerciseIsKept() throws {
        let resolution = ExerciseSubstitution.resolve(slug: "barbell-bench-press", catalog: try SeedFiles.catalog(), equipment: gym, limitations: [])
        #expect(resolution == .init(slug: "barbell-bench-press", replacedBecause: nil, isFallback: false))
    }

    @Test func lowerBackSwapsBentOverRow() throws {
        // Spec example: lower back pain → chest-supported dumbbell row instead of barbell bent-over row
        let resolution = ExerciseSubstitution.resolve(slug: "barbell-bent-over-row", catalog: try SeedFiles.catalog(), equipment: gym, limitations: [.lowerBack])
        #expect(resolution.slug == "chest-supported-row")
        #expect(resolution.replacedBecause == .injuryRisk([.lowerBack]))
    }

    @Test func missingEquipment() throws {
        var noDipBars = gym
        noDipBars.remove(.dipBars)
        let resolution = ExerciseSubstitution.resolve(slug: "chest-dips", catalog: try SeedFiles.catalog(), equipment: noDipBars, limitations: [])
        #expect(resolution.slug == "machine-chest-press")
        #expect(resolution.replacedBecause == .missingEquipment([.dipBars]))
    }

    @Test func kneesSwapSquatForSafeQuadsExercise() throws {
        let catalog = try SeedFiles.catalog()
        let resolution = ExerciseSubstitution.resolve(slug: "barbell-back-squat", catalog: catalog, equipment: gym, limitations: [.knees, .lowerBack])
        let chosen = try #require(catalog[resolution.slug])
        #expect(!resolution.isFallback || chosen.slug == "barbell-back-squat")
        if !resolution.isFallback {
            #expect(chosen.riskAreas.allSatisfy { ![.knees, .lowerBack].contains($0) })
        }
    }

    @Test func dumbbellsOnlyGym() throws {
        let catalog = try SeedFiles.catalog()
        let home: Set<Equipment> = [.dumbbells, .adjustableBench, .bodyweight]
        let bench = ExerciseSubstitution.resolve(slug: "barbell-bench-press", catalog: catalog, equipment: home, limitations: [])
        #expect(bench.slug == "dumbbell-bench-press")
        let pulldown = ExerciseSubstitution.resolve(slug: "lat-pulldown", catalog: catalog, equipment: home, limitations: [])
        // No bar, no cables: one-arm dumbbell row is the reachable back alternative
        #expect(catalog[pulldown.slug]?.equipment.allSatisfy(home.contains) == true || pulldown.isFallback)
    }

    @Test func fallbackWhenNothingFits() {
        let catalog = [
            "a": ExerciseInfo(slug: "a", primary: [.chest], secondary: [], equipment: [.machines], riskAreas: [], alternatives: ["b"]),
            "b": ExerciseInfo(slug: "b", primary: [.chest], secondary: [], equipment: [.machines], riskAreas: [], alternatives: ["a"])
        ]
        let resolution = ExerciseSubstitution.resolve(slug: "a", catalog: catalog, equipment: [], limitations: [])
        #expect(resolution.isFallback)
        #expect(resolution.slug == "a")
        #expect(ExerciseSubstitution.resolve(slug: "unknown", catalog: catalog, equipment: [], limitations: []).slug == "unknown")
    }

    @Test func alternativeMustTrainSameMuscle() {
        let catalog = [
            "a": ExerciseInfo(slug: "a", primary: [.chest], secondary: [], equipment: [.machines], riskAreas: [], alternatives: ["b", "c"]),
            "b": ExerciseInfo(slug: "b", primary: [.back], secondary: [], equipment: [], riskAreas: [], alternatives: []),
            "c": ExerciseInfo(slug: "c", primary: [.chest], secondary: [], equipment: [], riskAreas: [], alternatives: [])
        ]
        #expect(ExerciseSubstitution.resolve(slug: "a", catalog: catalog, equipment: [], limitations: []).slug == "c")
    }
}

@Suite("Substitution scenarios")
struct SubstitutionScenarioTests {
    @Test func kneesOrLowerBackGetLegPressInsteadOfSquat() throws {
        let catalog = try SeedFiles.catalog()
        let gym = Set(Equipment.allCases)
        for area in [InjuryArea.knees, .lowerBack] {
            let resolution = ExerciseSubstitution.resolve(slug: "barbell-back-squat", catalog: catalog, equipment: gym, limitations: [area])
            #expect(resolution.slug == "leg-press", "\(area)")
        }
    }
}
