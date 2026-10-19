import Foundation
import SwiftData
import ZalizoCore

enum SeedError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): String(localized: "Не знайдено вбудований файл \(name)")
        }
    }
}

/// Loads bundled seed data into the database. Re-running is safe: user edits are never overwritten.
@MainActor
enum SeedLoader {
    static func seedAll(context: ModelContext, bundle: Bundle = .main) {
        do {
            try seedExercises(context: context, bundle: bundle)
        } catch {
            Log.data.error("Exercise seed failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func seedExercises(context: ModelContext, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "exercises", withExtension: "json") else {
            throw SeedError.missingResource("exercises.json")
        }
        try seedExercises(ExerciseSeedFile.decode(Data(contentsOf: url)), context: context)
    }

    static func seedExercises(_ file: ExerciseSeedFile, context: ModelContext) throws {
        guard let settings = ProfileStore.settings(in: context), settings.exercisesSeedVersion < file.version else { return }
        let existing = try context.fetch(FetchDescriptor<Exercise>())
        let bySlug = Dictionary(existing.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        let plan = SeedMerge.plan(
            seedVersion: file.version,
            seedSlugs: file.exercises.map(\.slug),
            existing: bySlug.mapValues { SeedMerge.ExistingState(seedVersion: $0.seedVersion, userModified: $0.userModified) }
        )
        let seeds = Dictionary(file.exercises.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        for action in plan {
            switch action {
            case .insert(let slug):
                guard let seed = seeds[slug] else { continue }
                let exercise = Exercise(slug: slug, nameUk: seed.nameUk)
                apply(seed, to: exercise, version: file.version)
                context.insert(exercise)
            case .update(let slug):
                guard let seed = seeds[slug], let exercise = bySlug[slug] else { continue }
                apply(seed, to: exercise, version: file.version)
            case .keepUserVersion, .upToDate:
                continue
            }
        }
        settings.exercisesSeedVersion = file.version
        try context.save()
    }

    /// Copies seed content; keeps user state (favorite, custom photo).
    static func apply(_ seed: ExerciseSeed, to exercise: Exercise, version: Int) {
        exercise.nameUk = seed.nameUk
        exercise.nameEn = seed.nameEn
        exercise.synonyms = seed.synonyms
        exercise.primaryMusclesRaw = seed.primaryMuscles.map(\.rawValue)
        exercise.secondaryMusclesRaw = seed.secondaryMuscles.map(\.rawValue)
        exercise.equipmentRaw = seed.equipment.map(\.rawValue)
        exercise.mechanicRaw = seed.mechanic.rawValue
        exercise.levelRaw = seed.level.rawValue
        exercise.regionRaw = seed.region.rawValue
        exercise.progressionRaw = seed.progression.rawValue
        exercise.techniqueSteps = seed.techniqueSteps
        exercise.commonMistakes = seed.commonMistakes
        exercise.safetyTips = seed.safetyTips
        exercise.breathing = seed.breathing
        exercise.alternatives = seed.alternatives
        exercise.riskAreasRaw = seed.riskAreas.map(\.rawValue)
        exercise.imageNames = seed.imageNames
        exercise.isCustom = false
        exercise.seedVersion = version
    }
}
