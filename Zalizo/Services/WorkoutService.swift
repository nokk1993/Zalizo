import Foundation
import SwiftData
import ZalizoCore

/// Builds workouts from program days, reads exercise history and stores results.
@MainActor
enum WorkoutService {
    // MARK: Queries

    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { !$0.isFinished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func finishedSessions(in context: ModelContext) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isFinished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Past performances of an exercise, newest first (working sets only, current session excluded).
    static func history(for slug: String, excluding sessionID: UUID? = nil, limit: Int = 6, in context: ModelContext) -> [ExerciseHistoryEntry] {
        let descriptor = FetchDescriptor<PerformedExercise>(predicate: #Predicate { $0.exerciseSlug == slug && !$0.isSkipped })
        let performed = ((try? context.fetch(descriptor)) ?? []).filter { item in
            guard let session = item.session, session.isFinished else { return false }
            return session.id != sessionID
        }
        return performed
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
            .prefix(limit)
            .compactMap { item in
                let sets = item.workingSets.map { PerformedSet(weight: $0.weightKg, reps: $0.reps, rir: $0.rir) }
                guard !sets.isEmpty, let session = item.session else { return nil }
                return ExerciseHistoryEntry(date: session.startedAt, sets: sets, wasDeload: session.isDeload)
            }
    }

    /// All-time bests of an exercise from finished workouts.
    static func bests(for slug: String, excluding sessionID: UUID?, in context: ModelContext, formula: OneRMFormula) -> ExerciseBests {
        let entries = history(for: slug, excluding: sessionID, limit: .max, in: context)
        return ExerciseBests(sets: entries.flatMap(\.sets), formula: formula)
    }

    static func baselineOneRM(for slug: String, in context: ModelContext, formula: OneRMFormula) -> Double? {
        let descriptor = FetchDescriptor<StrengthBaseline>(predicate: #Predicate { $0.exerciseSlug == slug })
        guard let baseline = try? context.fetch(descriptor).first else { return nil }
        return OneRM.estimate(weight: baseline.weightKg, reps: baseline.reps, formula: formula).value
    }

    static func exercise(_ slug: String, in context: ModelContext) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == slug })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: Plans & prescriptions

    static func loadSettings(in context: ModelContext) -> LoadSettings {
        let settings = ProfileStore.settings(in: context)
        let profile = ProfileStore.profile(in: context)
        return LoadSettings(
            barbellStepKg: settings?.barbellStepKg ?? Defaults.barbellStepKg,
            dumbbellStepKg: settings?.dumbbellStepKg ?? Defaults.dumbbellStepKg,
            dumbbellMaxKg: profile?.dumbbellMaxKg ?? Defaults.dumbbellMaxKg,
            machineStepKg: settings?.machineStepKg ?? Defaults.machineStepKg,
            barWeightKg: settings?.barWeightKg ?? Defaults.barWeightKg
        )
    }

    static func plan(for performed: PerformedExercise, exercise: Exercise?, settings: LoadSettings) -> ExercisePlan {
        ExercisePlan(
            sets: performed.plannedSets, repMin: performed.repMin, repMax: performed.repMax, targetRIR: performed.targetRIR,
            load: LoadKind.from(equipment: exercise?.equipment ?? [.bodyweight], progression: exercise?.progression ?? .doubleProgression, settings: settings),
            region: exercise?.region ?? .upper, mechanic: exercise?.mechanic ?? .compound
        )
    }

    static func prescription(for performed: PerformedExercise, exercise: Exercise?, sessionID: UUID?, in context: ModelContext) -> Prescription {
        let settings = loadSettings(in: context)
        return prescription(
            slug: performed.exerciseSlug, plan: plan(for: performed, exercise: exercise, settings: settings),
            sessionID: sessionID, settings: settings, in: context
        )
    }

    /// Prescription for a planned (not yet started) exercise — used by the Today screen.
    static func prescription(for planned: PlannedExercise, slug: String, exercise: Exercise?, in context: ModelContext) -> Prescription {
        let settings = loadSettings(in: context)
        let plan = ExercisePlan(
            sets: planned.sets, repMin: planned.repMin, repMax: planned.repMax, targetRIR: planned.targetRIR,
            load: LoadKind.from(equipment: exercise?.equipment ?? [.bodyweight], progression: exercise?.progression ?? .doubleProgression, settings: settings),
            region: exercise?.region ?? .upper, mechanic: exercise?.mechanic ?? .compound, incrementOverrideKg: planned.incrementKg
        )
        return prescription(slug: slug, plan: plan, sessionID: nil, settings: settings, in: context)
    }

    private static func prescription(slug: String, plan: ExercisePlan, sessionID: UUID?, settings: LoadSettings, in context: ModelContext) -> Prescription {
        let formula = ProfileStore.settings(in: context)?.oneRMFormula ?? .epley
        return ProgressionEngine.prescribe(
            plan: plan,
            history: history(for: slug, excluding: sessionID, in: context),
            baselineOneRM: baselineOneRM(for: slug, in: context, formula: formula),
            settings: settings, formula: formula
        )
    }

    // MARK: Building workouts

    struct Options {
        var isDeload = false
        var startedAt: Date = .now
    }

    /// Creates an unfinished session for a program day: substitutions applied, targets and warm-ups pre-filled.
    @discardableResult
    static func start(day: ProgramDay, options: Options = Options(), in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(startedAt: options.startedAt, title: day.name)
        session.programDayID = day.id
        session.isDeload = options.isDeload
        context.insert(session)

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let catalog = ProgramStore.catalog(exercises)
        let profile = ProfileStore.snapshot(in: context)
        var warmedUp: Set<MuscleGroup> = []

        for (index, planned) in day.orderedExercises.enumerated() {
            let resolved = ProgramStore.resolve(planned, catalog: catalog, profile: profile)
            let exercise = exercises.first { $0.slug == resolved.slug }
            let performed = PerformedExercise(order: index, exerciseSlug: resolved.slug, exerciseName: exercise?.nameUk ?? resolved.slug)
            performed.plannedSets = options.isDeload ? DeloadAdvisor.deloadSets(planned.sets) : planned.sets
            performed.repMin = planned.repMin
            performed.repMax = planned.repMax
            performed.restSeconds = planned.restSeconds
            performed.targetRIR = planned.targetRIR
            performed.note = planned.note
            session.exercises.append(performed)
            fillSets(performed, exercise: exercise, session: session, warmedUp: &warmedUp, in: context)
        }
        try? context.save()
        return session
    }

    /// Empty workout ("довільне тренування", possibly back-dated).
    @discardableResult
    static func startEmpty(title: String, startedAt: Date = .now, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(startedAt: startedAt, title: title)
        context.insert(session)
        try? context.save()
        return session
    }

    /// Appends an exercise to a running workout with default 3 × 8–12.
    @discardableResult
    static func add(_ exercise: Exercise, to session: WorkoutSession, in context: ModelContext) -> PerformedExercise {
        let isIsolation = exercise.mechanic == .isolation
        let performed = PerformedExercise(order: session.exercises.count, exerciseSlug: exercise.slug, exerciseName: exercise.nameUk)
        performed.plannedSets = 3
        performed.repMin = isIsolation ? 10 : 8
        performed.repMax = isIsolation ? 15 : 12
        performed.restSeconds = isIsolation ? 75 : 120
        session.exercises.append(performed)
        var warmedUp = Set(session.exercises.filter { $0.id != performed.id }.flatMap { exerciseMuscles($0.exerciseSlug, in: context) })
        fillSets(performed, exercise: exercise, session: session, warmedUp: &warmedUp, in: context)
        try? context.save()
        return performed
    }

    /// Swaps the exercise of a performed entry; uncompleted sets are re-planned for the new exercise.
    static func replace(_ performed: PerformedExercise, with exercise: Exercise, in context: ModelContext) {
        performed.exerciseSlug = exercise.slug
        performed.exerciseName = exercise.nameUk
        let pending = performed.sets.filter { !$0.isCompleted }
        performed.sets.removeAll { !$0.isCompleted }
        pending.forEach(context.delete)
        guard let session = performed.session else { return }
        var warmedUp: Set<MuscleGroup> = performed.sets.isEmpty ? [] : Set(exercise.primaryMuscles)
        fillSets(performed, exercise: exercise, session: session, warmedUp: &warmedUp, in: context)
        try? context.save()
    }

    private static func exerciseMuscles(_ slug: String, in context: ModelContext) -> [MuscleGroup] {
        exercise(slug, in: context)?.primaryMuscles ?? []
    }

    /// Warm-ups (first compound for a muscle group in the session) + working sets pre-filled with the prescription.
    private static func fillSets(
        _ performed: PerformedExercise, exercise: Exercise?, session: WorkoutSession,
        warmedUp: inout Set<MuscleGroup>, in context: ModelContext
    ) {
        let settings = loadSettings(in: context)
        let plan = plan(for: performed, exercise: exercise, settings: settings)
        let rx = prescription(for: performed, exercise: exercise, sessionID: session.id, in: context)
        var order = (performed.sets.map(\.order).max() ?? -1) + 1

        // Deload keeps the weight of the last normal session.
        let workingWeight = session.isDeload ? (rx.last?.topWeight ?? rx.weight) : rx.weight
        let primary = Set(exercise?.primaryMuscles ?? [])
        let needsWarmup = plan.mechanic == .compound && !primary.isSubset(of: warmedUp) && workingWeight > 0
        if needsWarmup {
            let bar: Double? = if case .barbell = plan.load { settings.barWeightKg } else { nil }
            let step = ProgressionEngine.roundingStep(for: plan, settings: settings)
            for warmup in WarmupGenerator.sets(workingWeight: workingWeight, mechanic: plan.mechanic, barWeight: bar, step: step) {
                performed.sets.append(SetEntry(order: order, weightKg: warmup.weight, reps: warmup.reps, isWarmup: true))
                order += 1
            }
        }
        warmedUp.formUnion(primary)

        let firstWeight = rx.kind == .calibrate ? Calibration.firstSetWeight(plan: plan, settings: settings) : workingWeight
        let completedWorking = performed.sets.filter { !$0.isWarmup && $0.isCompleted }.count
        for index in completedWorking..<max(completedWorking, performed.plannedSets) {
            let reps = rx.reps.indices.contains(index) ? rx.reps[index] : performed.repMin
            performed.sets.append(SetEntry(order: order, weightKg: rx.kind == .calibrate ? firstWeight : workingWeight, reps: reps))
            order += 1
        }
    }

    /// "Як ти сьогодні?" → −1 working set per exercise (never below 1).
    static func dropOneSet(in session: WorkoutSession, context: ModelContext) {
        for performed in session.exercises {
            let pending = performed.orderedSets.filter { !$0.isWarmup && !$0.isCompleted }
            if performed.orderedSets.filter({ !$0.isWarmup }).count > 1, let last = pending.last {
                performed.sets.removeAll { $0.id == last.id }
                context.delete(last)
                performed.plannedSets = max(1, performed.plannedSets - 1)
            }
        }
        try? context.save()
    }

    /// "Як ти сьогодні?" → −5 % weight on all pending sets.
    static func reduceWeight(in session: WorkoutSession, context: ModelContext) {
        let settings = loadSettings(in: context)
        for performed in session.exercises {
            let plan = plan(for: performed, exercise: exercise(performed.exerciseSlug, in: context), settings: settings)
            let step = ProgressionEngine.roundingStep(for: plan, settings: settings)
            for set in performed.sets where !set.isCompleted && set.weightKg > 0 {
                set.weightKg = WellnessAdvisor.reducedWeight(set.weightKg, step: step)
            }
        }
        try? context.save()
    }

    // MARK: Finishing

    /// Marks the workout finished, removes empty sets and stores new personal records.
    static func finish(_ session: WorkoutSession, feeling: Int?, note: String, at date: Date = .now, in context: ModelContext) {
        let formula = ProfileStore.settings(in: context)?.oneRMFormula ?? .epley
        for performed in session.exercises {
            let pending = performed.sets.filter { !$0.isCompleted }
            performed.sets.removeAll { !$0.isCompleted }
            pending.forEach(context.delete)
            var bests = bests(for: performed.exerciseSlug, excluding: session.id, in: context, formula: formula)
            let isFirstTime = bests == ExerciseBests()
            for set in performed.workingSets {
                let hits = bests.register(PerformedSet(weight: set.weightKg, reps: set.reps, rir: set.rir), formula: formula)
                guard !isFirstTime else { continue }
                for hit in hits {
                    let record = PersonalRecord(
                        exerciseSlug: performed.exerciseSlug, kind: hit.kind, value: hit.value,
                        weightKg: set.weightKg, reps: set.reps, date: set.completedAt ?? date
                    )
                    record.repTarget = hit.repTarget
                    record.sessionID = session.id
                    context.insert(record)
                }
            }
        }
        session.endedAt = session.endedAt ?? date
        session.feeling = feeling
        session.note = note
        session.isFinished = true
        try? context.save()
        HealthService.saveWorkout(start: session.startedAt, end: session.endedAt ?? date)
    }

    static func discard(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }

    /// Stats for the summary screen.
    static func stats(for session: WorkoutSession, until date: Date = .now) -> WorkoutStats {
        let end = session.endedAt ?? date
        return WorkoutStats(
            durationSeconds: Int(end.timeIntervalSince(session.startedAt)),
            sets: session.orderedExercises.map { performed in
                performed.orderedSets.filter(\.isCompleted).map { Volume.SetSample(weight: $0.weightKg, reps: $0.reps, isWarmup: $0.isWarmup) }
            }
        )
    }

    /// Previous finished workout of the same program day (for "порівняння з минулим разом").
    static func previousSession(like session: WorkoutSession, in context: ModelContext) -> WorkoutSession? {
        finishedSessions(in: context).first { other in
            other.id != session.id && other.startedAt < session.startedAt
                && (session.programDayID != nil ? other.programDayID == session.programDayID : other.title == session.title)
        }
    }
}
