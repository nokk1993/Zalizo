import Foundation
import SwiftData
import Testing
import ZalizoCore
@testable import Zalizo

@MainActor
@Suite("Workout service")
struct WorkoutServiceTests {
    func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        try Persistence.bootstrap(context)
        SeedLoader.seedAll(context: context)
        ProfileStore.profile(in: context)?.onboardingCompleted = true
        try context.save()
        return context
    }

    func dayA(_ context: ModelContext) throws -> ProgramDay {
        try #require(ProgramStore.activeProgram(in: context)?.orderedDays.first)
    }

    /// Completes all working sets with given reps at their current weight.
    func complete(_ session: WorkoutSession, reps: Int, weight: Double? = nil) {
        for performed in session.exercises {
            for set in performed.orderedSets {
                if let weight, !set.isWarmup { set.weightKg = weight }
                if !set.isWarmup { set.reps = reps }
                set.isCompleted = true
                set.completedAt = .now
            }
        }
    }

    @Test func startBuildsSetsFromPlan() throws {
        let context = try makeContext()
        ProfileStore.saveBaselines([.benchPress: LiftResult(weightKg: 70, reps: 10)], context: context)
        let session = WorkoutService.start(day: try dayA(context), in: context)
        let bench = try #require(session.orderedExercises.first)
        #expect(bench.exerciseSlug == "barbell-bench-press")
        #expect(bench.orderedSets.filter { !$0.isWarmup }.count == 4)
        #expect(bench.orderedSets.filter { !$0.isWarmup }.allSatisfy { $0.weightKg == 72.5 && $0.reps == 6 })
        // Full warm-up ramp for the first chest compound: bar, 40 %, 60 %, 80 %
        #expect(bench.orderedSets.filter(\.isWarmup).map(\.weightKg) == [20, 30, 42.5, 57.5])
        // Second chest compound: no warm-up
        let incline = session.orderedExercises[1]
        #expect(incline.orderedSets.allSatisfy { !$0.isWarmup })
        #expect(WorkoutService.activeSession(in: context)?.id == session.id)
    }

    @Test func progressionAcrossWorkouts() throws {
        let context = try makeContext()
        ProfileStore.saveBaselines([.benchPress: LiftResult(weightKg: 70, reps: 10)], context: context)
        let first = WorkoutService.start(day: try dayA(context), in: context)
        complete(first, reps: 8, weight: 70)
        WorkoutService.finish(first, feeling: 4, note: "", in: context)

        let second = WorkoutService.start(day: try dayA(context), in: context)
        let bench = try #require(second.orderedExercises.first)
        let working = bench.orderedSets.filter { !$0.isWarmup }
        // 70 × 8 in all sets (top of 6–8) → +2.5 kg and back to 6 reps
        #expect(working.allSatisfy { $0.weightKg == 72.5 && $0.reps == 6 })
    }

    @Test func recordsAreStoredFromSecondWorkout() throws {
        let context = try makeContext()
        let first = WorkoutService.start(day: try dayA(context), in: context)
        complete(first, reps: 8, weight: 60)
        WorkoutService.finish(first, feeling: nil, note: "", in: context)
        #expect(try context.fetchCount(FetchDescriptor<PersonalRecord>()) == 0)

        let second = WorkoutService.start(day: try dayA(context), in: context)
        complete(second, reps: 8, weight: 65)
        WorkoutService.finish(second, feeling: nil, note: "", in: context)
        let records = try context.fetch(FetchDescriptor<PersonalRecord>()).filter { $0.exerciseSlug == "barbell-bench-press" }
        #expect(records.contains { $0.kind == .maxWeight && $0.value == 65 })
        #expect(records.contains { $0.kind == .repMax && $0.repTarget == 8 })
    }

    @Test func unfinishedSetsAreDroppedOnFinish() throws {
        let context = try makeContext()
        let session = WorkoutService.start(day: try dayA(context), in: context)
        let bench = try #require(session.orderedExercises.first)
        let firstWorking = try #require(bench.orderedSets.first { !$0.isWarmup })
        firstWorking.isCompleted = true
        WorkoutService.finish(session, feeling: 3, note: "Легко", in: context)
        #expect(session.isFinished)
        #expect(bench.sets.count == 1)
        #expect(session.orderedExercises[1].sets.isEmpty)
        #expect(WorkoutService.activeSession(in: context) == nil)
    }

    @Test func wellnessReductions() throws {
        let context = try makeContext()
        ProfileStore.saveBaselines([.benchPress: LiftResult(weightKg: 100, reps: 5)], context: context)
        let session = WorkoutService.start(day: try dayA(context), in: context)
        let bench = try #require(session.orderedExercises.first)
        let before = try #require(bench.orderedSets.first { !$0.isWarmup }?.weightKg)
        WorkoutService.dropOneSet(in: session, context: context)
        #expect(bench.orderedSets.filter { !$0.isWarmup }.count == 3)
        WorkoutService.reduceWeight(in: session, context: context)
        let after = try #require(bench.orderedSets.first { !$0.isWarmup }?.weightKg)
        #expect(after < before)
    }

    @Test func deloadHalvesSets() throws {
        let context = try makeContext()
        let session = WorkoutService.start(day: try dayA(context), options: .init(isDeload: true), in: context)
        let bench = try #require(session.orderedExercises.first)
        #expect(bench.plannedSets == 2)
        #expect(session.isDeload)
    }

    @Test func todayRotatesProgramDays() throws {
        let context = try makeContext()
        let firstPlan = try #require(TodayPlanner.plan(in: context))
        #expect(firstPlan.day.order == 0)
        #expect(!firstPlan.previews.isEmpty)
        #expect(firstPlan.estimatedMinutes >= 30)

        let session = WorkoutService.start(day: firstPlan.day, in: context)
        complete(session, reps: 8, weight: 50)
        WorkoutService.finish(session, feeling: nil, note: "", in: context)
        let next = try #require(TodayPlanner.plan(in: context))
        #expect(next.day.order == 1)
        #expect(!next.next.isToday)
    }

    @Test func replaceExerciseKeepsCompletedSets() throws {
        let context = try makeContext()
        let session = WorkoutService.start(day: try dayA(context), in: context)
        let bench = try #require(session.orderedExercises.first)
        let firstSet = try #require(bench.orderedSets.first)
        firstSet.isCompleted = true
        let dumbbell = try #require(WorkoutService.exercise("dumbbell-bench-press", in: context))
        WorkoutService.replace(bench, with: dumbbell, in: context)
        #expect(bench.exerciseSlug == "dumbbell-bench-press")
        #expect(bench.sets.filter(\.isCompleted).count == 1)
        #expect(bench.sets.contains { !$0.isCompleted })
    }
}
