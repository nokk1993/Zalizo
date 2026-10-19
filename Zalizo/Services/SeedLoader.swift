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
        do {
            try seedPrograms(context: context, bundle: bundle)
        } catch {
            Log.data.error("Program seed failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func seedPrograms(context: ModelContext, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "programs", withExtension: "json") else {
            throw SeedError.missingResource("programs.json")
        }
        try seedPrograms(ProgramSeedFile.decode(Data(contentsOf: url)), context: context)
    }

    /// Built-in programs are inserted once and never overwritten - the user may have edited them.
    /// Only punctuation-level text fixes of untouched texts are applied on a seed version bump.
    static func seedPrograms(_ file: ProgramSeedFile, context: ModelContext) throws {
        guard let settings = ProfileStore.settings(in: context), settings.programsSeedVersion < file.version else { return }
        let programs = try context.fetch(FetchDescriptor<Program>())
        let seeds = Dictionary(file.programs.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        for program in programs where program.isBuiltIn {
            if let slug = program.seedSlug, let seed = seeds[slug] {
                refreshTexts(of: program, from: seed)
            }
        }
        let existing = Set(programs.compactMap(\.seedSlug))
        for seed in file.programs where !existing.contains(seed.slug) {
            context.insert(makeProgram(seed))
        }
        settings.programsSeedVersion = file.version
        try context.save()
    }

    /// Replaces a stored text with the seed text only if they differ by dash style alone,
    /// so user renames survive.
    static func refreshTexts(of program: Program, from seed: ProgramSeed) {
        func refreshed(_ stored: String, _ seedText: String) -> String {
            stored.shortDashes == seedText.shortDashes ? seedText : stored
        }
        program.name = refreshed(program.name, seed.name)
        program.summary = refreshed(program.summary, seed.summary)
        program.audience = refreshed(program.audience, seed.audience)
        program.progressionNotes = refreshed(program.progressionNotes, seed.progressionNotes)
        for day in program.days {
            guard let daySeed = seed.days.first(where: { $0.name.shortDashes == day.name.shortDashes }) else { continue }
            day.name = daySeed.name
            day.focus = refreshed(day.focus, daySeed.focus)
            for planned in day.exercises {
                if let item = daySeed.exercises.first(where: { $0.slug == planned.exerciseSlug }) {
                    planned.note = refreshed(planned.note, item.note)
                }
            }
        }
    }

    static func makeProgram(_ seed: ProgramSeed) -> Program {
        let program = Program(name: seed.name)
        program.summary = seed.summary
        program.audience = seed.audience
        program.recommendedWeeks = seed.recommendedWeeks
        program.progressionNotes = seed.progressionNotes
        program.isBuiltIn = true
        program.seedSlug = seed.slug
        program.days = seed.days.enumerated().map { index, daySeed in
            let day = ProgramDay(order: index, name: daySeed.name, focus: daySeed.focus)
            day.exercises = daySeed.exercises.enumerated().map { order, item in
                let planned = PlannedExercise(
                    order: order, exerciseSlug: item.slug, sets: item.sets,
                    repMin: item.repMin, repMax: item.repMax, restSeconds: item.restSeconds
                )
                planned.targetRIR = item.targetRIR
                planned.note = item.note
                return planned
            }
            return day
        }
        return program
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

private extension String {
    /// Long dashes written as a short hyphen (the app's typography rule).
    var shortDashes: String {
        replacingOccurrences(of: "\u{2014}", with: "-").replacingOccurrences(of: "\u{2013}", with: "-")
    }
}
