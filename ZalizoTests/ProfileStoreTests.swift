import Foundation
import SwiftData
import Testing
import ZalizoCore
@testable import Zalizo

@MainActor
@Suite("ProfileStore & onboarding")
struct ProfileStoreTests {
    func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        try Persistence.bootstrap(context)
        return context
    }

    @Test func snapshotRoundTrip() throws {
        let context = try makeContext()
        let profile = try #require(ProfileStore.profile(in: context))
        var snapshot = ProfileSnapshot()
        snapshot.sex = .female
        snapshot.heightCm = 165
        snapshot.weightKg = 58.5
        snapshot.goal = .strength
        snapshot.trainingDays = [.tuesday, .thursday]
        snapshot.limitations = [.knees]
        snapshot.dietExclusions = [.dairy, .nuts]
        snapshot.targetWeightKg = 61
        snapshot.hasMicroPlates = false

        ProfileStore.apply(snapshot, to: profile, context: context)
        try context.save()

        let restored = ProfileStore.snapshot(in: context)
        #expect(restored == snapshot)
        #expect(ProfileStore.settings(in: context)?.barbellStepKg == 5)
    }

    @Test func oneWeightEntryPerDay() throws {
        let context = try makeContext()
        ProfileStore.recordWeight(70, context: context)
        ProfileStore.recordWeight(70.4, context: context)
        try context.save()
        let entries = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.weightKg == 70.4)

        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: .now))
        ProfileStore.recordWeight(69.8, on: yesterday, context: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<BodyWeightEntry>()) == 2)
        #expect(ProfileStore.latestWeight(in: context)?.weightKg == 70.4)
    }

    @Test func baselinesReplaceAndSkipInvalid() throws {
        let context = try makeContext()
        ProfileStore.saveBaselines([.benchPress: LiftResult(weightKg: 70, reps: 10), .squat: LiftResult(weightKg: 0, reps: 5)], context: context)
        try context.save()
        #expect(ProfileStore.baselines(in: context) == [.benchPress: LiftResult(weightKg: 70, reps: 10)])
        ProfileStore.saveBaselines([:], context: context)
        try context.save()
        #expect(ProfileStore.baselines(in: context).isEmpty)
    }

    @Test func onboardingResumesAndCompletes() throws {
        let context = try makeContext()
        let profile = try #require(ProfileStore.profile(in: context))

        let model = OnboardingModel(context: context, profile: profile)
        #expect(model.step == .welcome)
        #expect(ProfileStore.latestWeight(in: context) == nil) // no weight before the body step
        model.next() // → body
        model.snapshot.weightKg = 74.2
        model.snapshot.heightCm = 183
        model.next() // → goal (weight recorded)
        #expect(profile.onboardingStep == OnboardingStep.goal.rawValue)
        #expect(ProfileStore.latestWeight(in: context)?.weightKg == 74.2)

        // App closed and reopened: a new model resumes on the same step with the same answers.
        let resumed = OnboardingModel(context: context, profile: profile)
        #expect(resumed.step == .goal)
        #expect(resumed.snapshot.heightCm == 183)
        #expect(resumed.snapshot.weightKg == 74.2)

        resumed.snapshot.trainingDays = []
        resumed.step = .schedule
        #expect(!resumed.canProceed)
        resumed.skip() // defaults restored
        #expect(resumed.snapshot.trainingDays == Defaults.trainingDays)

        while resumed.step != .summary { resumed.next() }
        resumed.finish()
        #expect(profile.onboardingCompleted)
        #expect(profile.blockStartDate != nil)
    }

    @Test func skippingLiftsClearsBaselines() throws {
        let context = try makeContext()
        let profile = try #require(ProfileStore.profile(in: context))
        let model = OnboardingModel(context: context, profile: profile)
        model.step = .lifts
        model.knowsLifts = true
        model.lifts = [.overheadPress: LiftResult(weightKg: 40, reps: 8)]
        model.next()
        #expect(ProfileStore.baselines(in: context).count == 1)
        model.step = .lifts
        model.skip()
        #expect(ProfileStore.baselines(in: context).isEmpty)
    }
}
