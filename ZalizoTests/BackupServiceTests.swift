import Foundation
import SwiftData
import Testing
import ZalizoCore
@testable import Zalizo

@MainActor
@Suite("Backup round trip")
struct BackupServiceTests {
    func populatedContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        try Persistence.bootstrap(context)
        SeedLoader.seedAll(context: context)
        let profile = try #require(ProfileStore.profile(in: context))
        profile.onboardingCompleted = true
        profile.heightCm = 181
        profile.limitations = [.knees]
        ProfileStore.saveBaselines([.benchPress: LiftResult(weightKg: 70, reps: 10)], context: context)
        ProfileStore.recordWeight(72.5, on: .now.addingTimeInterval(-86_400 * 3), context: context)
        ProfileStore.recordWeight(73.1, context: context)
        context.insert(BodyMeasurement(date: .now, kind: .waist, valueCm: 81.5))
        let goal = Goal(kind: .bodyWeight, title: "Вага 78", startValue: 72.5, targetValue: 78)
        context.insert(goal)
        WorkoutService.exercise("hammer-curl", in: context)?.isFavorite = true

        let day = try #require(ProgramStore.activeProgram(in: context)?.orderedDays.first)
        day.name = "Мій день A"
        let session = WorkoutService.start(day: day, in: context)
        for performed in session.exercises {
            for set in performed.sets { set.isCompleted = true; set.completedAt = .now }
        }
        WorkoutService.finish(session, feeling: 4, note: "Ок", in: context)
        let log = try #require(NutritionStore.log(in: context))
        log.waterMl = 1500
        log.entries.append(FoodEntry(name: "Каша", kcal: 400, protein: 15))
        try context.save()
        return context
    }

    /// Comparable view of a backup (export time and backup date excluded).
    func normalized(_ file: BackupFile) -> BackupFile {
        var copy = file
        copy.exportedAt = .distantPast
        copy.settings?.lastBackupAt = nil
        copy.weights.sort { $0.id.uuidString < $1.id.uuidString }
        copy.sessions.sort { $0.id.uuidString < $1.id.uuidString }
        copy.records.sort { $0.id.uuidString < $1.id.uuidString }
        copy.programs.sort { $0.id.uuidString < $1.id.uuidString }
        copy.exerciseStates.sort { $0.slug < $1.slug }
        copy.achievements.sort { $0.key < $1.key }
        copy.baselines.sort { $0.id.uuidString < $1.id.uuidString }
        return copy
    }

    @Test func exportDeleteImportRestoresEverything() throws {
        let context = try populatedContext()
        let before = BackupService.makeBackup(in: context, includePhotos: false)
        let data = try BackupCodec.encode(before)

        DataReset.resetAll(in: context)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 0)
        #expect(ProfileStore.profile(in: context)?.onboardingCompleted == false)

        try BackupService.restore(try BackupService.decode(data), mode: .replaceAll, in: context)
        let after = BackupService.makeBackup(in: context, includePhotos: false)
        #expect(normalized(after) == normalized(before))
        #expect(ProfileStore.profile(in: context)?.onboardingCompleted == true)
        #expect(WorkoutService.finishedSessions(in: context).count == 1)
    }

    @Test func mergeAddsOnlyMissing() throws {
        let context = try populatedContext()
        let file = BackupService.makeBackup(in: context, includePhotos: false)
        let summary = try BackupService.restore(file, mode: .merge, in: context)
        #expect(summary.workouts == 0)
        #expect(summary.weights == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 1)
    }

    @Test func rejectsForeignFiles() {
        #expect(throws: BackupService.BackupError.self) {
            try BackupService.decode(Data("{}".utf8))
        }
    }

    @Test func csvExport() throws {
        let context = try populatedContext()
        let url = try BackupService.exportCSV(in: context)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("Жим штанги лежачи"))
        #expect(text.contains(CSVExport.header))
    }
}
