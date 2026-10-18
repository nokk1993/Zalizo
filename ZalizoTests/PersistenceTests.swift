import Foundation
import SwiftData
import Testing
import ZalizoCore
@testable import Zalizo

@MainActor
@Suite("Persistence")
struct PersistenceTests {
    @Test func bootstrapCreatesSingleProfileAndSettings() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        try Persistence.bootstrap(context)
        try Persistence.bootstrap(context) // idempotent

        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<AppSettings>()) == 1)

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.onboardingCompleted == false)
        #expect(profile.goal == .muscleGain)
        #expect(profile.weekdays == [.monday, .wednesday, .friday])
    }

    @Test func profileEnumAccessorsRoundTrip() {
        let profile = UserProfile()
        profile.sex = .female
        profile.limitations = [.knees, .lowerBack]
        profile.weekdays = [.friday, .tuesday]
        #expect(profile.sexRaw == "female")
        #expect(profile.limitationsRaw == ["knees", "lowerBack"])
        #expect(profile.trainingWeekdays == [2, 5])
    }

    @Test func workoutCascadeDelete() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let session = WorkoutSession(title: "Демо")
        let performed = PerformedExercise(order: 0, exerciseSlug: "barbell-bench-press", exerciseName: "Жим лежачи")
        performed.sets = [SetEntry(order: 0, weightKg: 60, reps: 10), SetEntry(order: 1, weightKg: 60, reps: 9)]
        session.exercises = [performed]
        context.insert(session)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 2)

        context.delete(session)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PerformedExercise>()) == 0)
    }

    @Test func exerciseSlugIsUnique() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Exercise(slug: "squat", nameUk: "Присідання"))
        try context.save()
        // Unique attribute → upsert, not a duplicate row.
        context.insert(Exercise(slug: "squat", nameUk: "Присідання зі штангою"))
        try context.save()
        let all = try context.fetch(FetchDescriptor<Exercise>())
        #expect(all.count == 1)
        #expect(all.first?.nameUk == "Присідання зі штангою")
    }
}
