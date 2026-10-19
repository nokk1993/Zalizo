import Foundation
import SwiftData
import Testing
import ZalizoCore
@testable import Zalizo

@MainActor
@Suite("Program store")
struct ProgramStoreTests {
    func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        try Persistence.bootstrap(context)
        SeedLoader.seedAll(context: context)
        return context
    }

    @Test func builtInProgramsSeededOnce() throws {
        let context = try makeContext()
        #expect(ProgramStore.programs(in: context).count == 5)
        try SeedLoader.seedPrograms(context: context)
        #expect(ProgramStore.programs(in: context).count == 5)
        let split = try #require(ProgramStore.programs(in: context).first { $0.seedSlug == ProgramCatalog.massSplit3 })
        #expect(split.orderedDays.map(\.exercises.count) == [7, 8, 8])
        #expect(split.orderedDays.first?.orderedExercises.first?.exerciseSlug == "barbell-bench-press")
    }

    @Test func activeProgramDefaultsToRecommendation() throws {
        let context = try makeContext()
        let active = try #require(ProgramStore.activeProgram(in: context))
        #expect(active.seedSlug == ProgramCatalog.massSplit3) // default: 3 days a week
        #expect(ProgramStore.profile(in: context)?.activeProgramID == active.id)
    }

    @Test func duplicateIsDeepAndIndependent() throws {
        let context = try makeContext()
        let original = try #require(ProgramStore.programs(in: context).first { $0.seedSlug == ProgramCatalog.ppl3 })
        let copy = ProgramStore.duplicate(original, context: context)
        #expect(!copy.isBuiltIn)
        #expect(copy.seedSlug == nil)
        #expect(copy.days.count == original.days.count)
        copy.orderedDays.first?.orderedExercises.first?.sets = 6
        #expect(original.orderedDays.first?.orderedExercises.first?.sets == 4)
    }

    @Test func volumeUsesSubstitutedExercises() throws {
        let context = try makeContext()
        let program = try #require(ProgramStore.programs(in: context).first { $0.seedSlug == ProgramCatalog.massSplit3 })
        let catalog = ProgramStore.catalog(try context.fetch(FetchDescriptor<Exercise>()))
        var profile = ProfileSnapshot()
        let full = ProgramStore.weeklyVolume(program, catalog: catalog, profile: profile)
        #expect((full[.chest] ?? 0) >= 10)

        profile.limitations = [.lowerBack]
        let row = try #require(program.orderedDays[1].orderedExercises.first { $0.exerciseSlug == "barbell-bent-over-row" })
        #expect(ProgramStore.resolve(row, catalog: catalog, profile: profile).slug == "chest-supported-row")
    }

    @Test func reorderRenumbers() throws {
        let context = try makeContext()
        let program = try #require(ProgramStore.activeProgram(in: context))
        let days = program.orderedDays
        ProgramStore.reorder(days, from: IndexSet(integer: 2), to: 0) { $0.order = $1 }
        #expect(program.orderedDays.map(\.name) == [days[2].name, days[0].name, days[1].name])
    }
}

private extension ProgramStore {
    static func profile(in context: ModelContext) -> UserProfile? { ProfileStore.profile(in: context) }
}

private extension ProgramCatalog {
    static let ppl3 = pushPullLegs3
}
