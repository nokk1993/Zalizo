import Foundation
import SwiftData
import Testing
import ZalizoCore
@testable import Zalizo

@MainActor
@Suite("Seed loader")
struct SeedLoaderTests {
    func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        try Persistence.bootstrap(context)
        return context
    }

    @Test func bundledSeedLoads() throws {
        let context = try makeContext()
        try SeedLoader.seedExercises(context: context)
        let count = try context.fetchCount(FetchDescriptor<Exercise>())
        #expect(count >= 60)
        let bench = try #require(try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == "barbell-bench-press" })).first)
        #expect(bench.nameUk == "Жим штанги лежачи")
        #expect(bench.primaryMuscles == [.chest])
        #expect(bench.imageNames.count == 2)
    }

    @Test func seedIsIdempotentAndRespectsUserEdits() throws {
        let context = try makeContext()
        let seed = ExerciseSeed(
            slug: "demo", nameUk: "Демо", nameEn: "Demo", synonyms: [], primaryMuscles: [.chest], secondaryMuscles: [],
            equipment: [.barbell], mechanic: .compound, level: .beginner, region: .upper, progression: .doubleProgression,
            techniqueSteps: ["1", "2", "3", "4"], commonMistakes: ["a", "b", "c"], safetyTips: ["s"], breathing: "b",
            alternatives: [], riskAreas: [], imageNames: [], source: nil
        )
        try SeedLoader.seedExercises(ExerciseSeedFile(version: 1, exercises: [seed]), context: context)
        try SeedLoader.seedExercises(ExerciseSeedFile(version: 1, exercises: [seed]), context: context)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)

        let exercise = try #require(try context.fetch(FetchDescriptor<Exercise>()).first)
        exercise.isFavorite = true
        exercise.customImageFileName = "mine.jpg"

        var renamed = seed
        renamed.nameUk = "Демо 2"
        try SeedLoader.seedExercises(ExerciseSeedFile(version: 2, exercises: [renamed]), context: context)
        #expect(exercise.nameUk == "Демо 2") // not edited by the user → updated
        #expect(exercise.isFavorite) // user state kept
        #expect(exercise.customImageFileName == "mine.jpg")

        exercise.userModified = true
        exercise.nameUk = "Моя назва"
        renamed.nameUk = "Демо 3"
        try SeedLoader.seedExercises(ExerciseSeedFile(version: 3, exercises: [renamed]), context: context)
        #expect(exercise.nameUk == "Моя назва") // user edit wins
    }

    @Test func programTextFixKeepsUserRenames() throws {
        let context = try makeContext()
        let url = try #require(Bundle.main.url(forResource: "programs", withExtension: "json"))
        var file = try ProgramSeedFile.decode(Data(contentsOf: url))
        file.programs = Array(file.programs.prefix(1))
        file.programs[0].summary = "Спліт - три дні"
        file.programs[0].days[0].focus = "Груди - біцепс"
        file.version = 1
        try SeedLoader.seedPrograms(file, context: context)
        let program = try #require(try context.fetch(FetchDescriptor<Program>()).first)

        // Texts as an older build stored them, plus one user edit.
        program.summary = "Спліт \u{2014} три дні"
        program.orderedDays[0].focus = "Мій фокус"
        file.version = 2
        try SeedLoader.seedPrograms(file, context: context)

        #expect(program.summary == "Спліт - три дні")
        #expect(program.orderedDays[0].focus == "Мій фокус")
        #expect(try context.fetchCount(FetchDescriptor<Program>()) == 1)
    }
}
