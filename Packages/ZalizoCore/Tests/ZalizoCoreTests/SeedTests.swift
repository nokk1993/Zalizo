import Foundation
import Testing
@testable import ZalizoCore

/// Validates the real seed files shipped in the app bundle.
enum SeedFiles {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ZalizoCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ZalizoCore
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo

    static func url(_ relative: String) -> URL { repoRoot.appending(path: relative) }

    static func exercises() throws -> ExerciseSeedFile {
        try ExerciseSeedFile.decode(Data(contentsOf: url("Zalizo/Resources/Seed/exercises.json")))
    }
}

@Suite("Exercise seed")
struct ExerciseSeedTests {
    @Test func decodesAndHasEnoughExercises() throws {
        let file = try SeedFiles.exercises()
        #expect(file.version >= 1)
        #expect((60...120).contains(file.exercises.count))
    }

    @Test func slugsAreUniqueAndAlternativesResolve() throws {
        let exercises = try SeedFiles.exercises().exercises
        let slugs = Set(exercises.map(\.slug))
        #expect(slugs.count == exercises.count)
        for exercise in exercises {
            for alternative in exercise.alternatives {
                #expect(slugs.contains(alternative), "\(exercise.slug) → \(alternative)")
            }
            #expect(!exercise.alternatives.contains(exercise.slug))
        }
    }

    @Test func contentIsComplete() throws {
        for exercise in try SeedFiles.exercises().exercises {
            #expect((4...7).contains(exercise.techniqueSteps.count), "\(exercise.slug) steps")
            #expect((3...5).contains(exercise.commonMistakes.count), "\(exercise.slug) mistakes")
            #expect(!exercise.safetyTips.isEmpty, "\(exercise.slug) safety")
            #expect(!exercise.breathing.isEmpty)
            #expect(!exercise.primaryMuscles.isEmpty)
            #expect(!exercise.equipment.isEmpty)
            #expect(!exercise.nameUk.isEmpty && !exercise.nameEn.isEmpty)
            #expect(exercise.imageNames.count == 2)
        }
    }

    @Test func keyLiftsExist() throws {
        let slugs = Set(try SeedFiles.exercises().exercises.map(\.slug))
        for lift in KeyLift.allCases {
            #expect(slugs.contains(lift.rawValue), "\(lift.rawValue)")
        }
    }

    @Test func imagesArePresentInAssetCatalog() throws {
        let assets = SeedFiles.url("Zalizo/Resources/Assets.xcassets/Exercises")
        for exercise in try SeedFiles.exercises().exercises {
            for name in exercise.imageNames {
                let file = assets.appending(path: "\(name).imageset/\(name).jpg")
                #expect(FileManager.default.fileExists(atPath: file.path), "\(name)")
            }
        }
    }

    @Test func everyMuscleGroupIsCovered() throws {
        let covered = Set(try SeedFiles.exercises().exercises.flatMap(\.primaryMuscles))
        #expect(covered.isSuperset(of: [.chest, .back, .shoulders, .biceps, .triceps, .quads, .hamstrings, .glutes, .calves, .abs, .traps]))
    }
}

@Suite("Seed merge")
struct SeedMergeTests {
    @Test func planActions() {
        let actions = SeedMerge.plan(seedVersion: 2, seedSlugs: ["new", "old", "edited", "current"], existing: [
            "old": .init(seedVersion: 1, userModified: false),
            "edited": .init(seedVersion: 1, userModified: true),
            "current": .init(seedVersion: 2, userModified: false)
        ])
        #expect(actions == [.insert(slug: "new"), .update(slug: "old"), .keepUserVersion(slug: "edited"), .upToDate(slug: "current")])
    }
}

@Suite("Search")
struct SearchTextTests {
    @Test func normalisation() {
        #expect(SearchText.normalize("  Жим ЛЕЖАЧИ ") == "жим лежачи")
        #expect(SearchText.normalize("Зап’ястя") == "зап'ястя")
    }

    @Test func matching() {
        let fields = ["Жим штанги лежачи", "Barbell Bench Press", "бенч"]
        #expect(SearchText.matches(query: "жим лежачи", fields: fields))
        #expect(SearchText.matches(query: "bench", fields: fields))
        #expect(SearchText.matches(query: "", fields: fields))
        #expect(!SearchText.matches(query: "присідання", fields: fields))
        #expect(SearchText.matches(query: "лежачи штанги", fields: fields)) // word order does not matter
    }
}
