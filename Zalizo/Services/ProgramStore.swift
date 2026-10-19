import Foundation
import SwiftData
import SwiftUI
import ZalizoCore

/// Active program selection, copying, substitution and volume for programs stored in SwiftData.
@MainActor
enum ProgramStore {
    static func programs(in context: ModelContext) -> [Program] {
        (try? context.fetch(FetchDescriptor<Program>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    /// The active program; falls back to the recommended built-in one (and remembers it).
    static func activeProgram(in context: ModelContext) -> Program? {
        guard let profile = ProfileStore.profile(in: context) else { return nil }
        let all = programs(in: context)
        if let id = profile.activeProgramID, let program = all.first(where: { $0.id == id }) {
            return program
        }
        let snapshot = ProfileStore.snapshot(in: context)
        let slug = ProgramCatalog.recommendedSlug(daysPerWeek: snapshot.trainingDays.count, experience: snapshot.experience)
        guard let program = all.first(where: { $0.seedSlug == slug }) ?? all.first else { return nil }
        profile.activeProgramID = program.id
        try? context.save()
        return program
    }

    static func activate(_ program: Program, context: ModelContext) {
        guard let profile = ProfileStore.profile(in: context) else { return }
        if profile.activeProgramID != program.id {
            profile.activeProgramID = program.id
            profile.blockStartDate = .now
        }
        try? context.save()
    }

    static func activate(seedSlug: String, context: ModelContext) {
        if let program = programs(in: context).first(where: { $0.seedSlug == seedSlug }) {
            activate(program, context: context)
        }
    }

    /// "Скопіювати і редагувати": deep copy that is never touched by seeds.
    @discardableResult
    static func duplicate(_ program: Program, context: ModelContext) -> Program {
        let copy = Program(name: String(localized: "\(program.name) (копія)"))
        copy.summary = program.summary
        copy.audience = program.audience
        copy.recommendedWeeks = program.recommendedWeeks
        copy.progressionNotes = program.progressionNotes
        copy.days = program.orderedDays.map { day in
            let newDay = ProgramDay(order: day.order, name: day.name, focus: day.focus)
            newDay.exercises = day.orderedExercises.map { item in
                let planned = PlannedExercise(
                    order: item.order, exerciseSlug: item.exerciseSlug, sets: item.sets,
                    repMin: item.repMin, repMax: item.repMax, restSeconds: item.restSeconds
                )
                planned.targetRIR = item.targetRIR
                planned.progressionRaw = item.progressionRaw
                planned.incrementKg = item.incrementKg
                planned.note = item.note
                return planned
            }
            return newDay
        }
        context.insert(copy)
        try? context.save()
        return copy
    }

    /// New empty program with `days` training days.
    @discardableResult
    static func createProgram(name: String, days: Int, context: ModelContext) -> Program {
        let program = Program(name: name)
        program.days = (0..<max(1, days)).map { index in
            ProgramDay(order: index, name: String(localized: "День \(index + 1)"))
        }
        context.insert(program)
        try? context.save()
        return program
    }

    // MARK: Exercise catalog & substitution

    static func catalog(_ exercises: [Exercise]) -> [String: ExerciseInfo] {
        Dictionary(exercises.map { ($0.slug, $0.info) }, uniquingKeysWith: { first, _ in first })
    }

    static func resolve(_ planned: PlannedExercise, catalog: [String: ExerciseInfo], profile: ProfileSnapshot) -> ExerciseSubstitution.Resolution {
        ExerciseSubstitution.resolve(slug: planned.exerciseSlug, catalog: catalog, equipment: profile.equipment, limitations: profile.limitations)
    }

    /// Weekly sets per muscle using the exercises actually performed (after substitution).
    static func weeklyVolume(_ program: Program, catalog: [String: ExerciseInfo], profile: ProfileSnapshot) -> [MuscleGroup: Double] {
        let days = program.orderedDays.map { day in
            day.orderedExercises.map { planned in
                ProgramVolume.DayExercise(slug: resolve(planned, catalog: catalog, profile: profile).slug, sets: planned.sets)
            }
        }
        return ProgramVolume.weeklySets(days: days, sessionsPerWeek: profile.sessionsPerWeek, catalog: catalog)
    }

    /// Renumbers `order` after a move in a list.
    static func reorder<T>(_ items: [T], from source: IndexSet, to destination: Int, setOrder: (T, Int) -> Void) {
        var moved = items
        moved.move(fromOffsets: source, toOffset: destination)
        for (index, item) in moved.enumerated() {
            setOrder(item, index)
        }
    }
}

extension Exercise {
    var info: ExerciseInfo {
        ExerciseInfo(
            slug: slug, primary: primaryMuscles, secondary: secondaryMuscles, equipment: equipment,
            riskAreas: riskAreas, alternatives: alternatives, mechanic: mechanic, region: region, progression: progression
        )
    }
}
