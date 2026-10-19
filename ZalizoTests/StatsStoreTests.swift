import Foundation
import SwiftData
import Testing
import ZalizoCore
@testable import Zalizo

@MainActor
@Suite("Stats store")
struct StatsStoreTests {
    @Test func onlyFinishedWorkingSetsAreCounted() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let bench = Exercise(slug: "bench", nameUk: "Жим")
        bench.primaryMusclesRaw = ["chest"]
        context.insert(bench)

        let finished = WorkoutSession(startedAt: .now, title: "A")
        finished.isFinished = true
        let performed = PerformedExercise(order: 0, exerciseSlug: "bench", exerciseName: "Жим")
        let warmup = SetEntry(order: 0, weightKg: 20, reps: 10, isWarmup: true)
        warmup.isCompleted = true
        let working = SetEntry(order: 1, weightKg: 70, reps: 8)
        working.isCompleted = true
        performed.sets = [warmup, working, SetEntry(order: 2, weightKg: 70, reps: 8)]
        finished.exercises = [performed]
        context.insert(finished)
        context.insert(WorkoutSession(title: "Running"))
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let records = StatsStore.records(sessions, exercises: [bench])
        #expect(records.count == 1)
        #expect(records.first?.exercises.first?.sets == [PerformedSet(weight: 70, reps: 8)])
        #expect(records.first?.exercises.first?.primary == [.chest])
    }
}
