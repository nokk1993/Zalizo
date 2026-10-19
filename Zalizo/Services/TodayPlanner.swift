import Foundation
import SwiftData
import ZalizoCore

/// Everything the Today screen shows, computed from the active program, history and profile.
@MainActor
enum TodayPlanner {
    struct ExercisePreview: Identifiable {
        let id: UUID
        let name: String
        let target: String
        let hint: String?
        let last: String?
        let kind: Prescription.Kind
        let substitution: String?
    }

    struct Plan {
        let program: Program
        let day: ProgramDay
        let next: TrainingSchedule.Next
        let previews: [ExercisePreview]
        let estimatedMinutes: Int
    }

    static func plan(in context: ModelContext, now: Date = .now) -> Plan? {
        guard let program = ProgramStore.activeProgram(in: context) else { return nil }
        let days = program.orderedDays
        guard !days.isEmpty else { return nil }
        let sessions = WorkoutService.finishedSessions(in: context)
        let profile = ProfileStore.snapshot(in: context)
        let calendar = Calendar.current
        let trainedToday = sessions.contains { calendar.isDate($0.startedAt, inSameDayAs: now) }
        let lastIndex = lastDayIndex(days: days, sessions: sessions)
        guard let next = TrainingSchedule.next(
            trainingDays: profile.trainingDays, dayCount: days.count, lastDayIndex: lastIndex,
            trainedToday: trainedToday, today: now, calendar: calendar
        ) else { return nil }
        let day = days[next.dayIndex]

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let catalog = ProgramStore.catalog(exercises)
        var warmed: Set<MuscleGroup> = []
        var estimateItems: [SessionEstimate.Item] = []
        let deload = isDeloadWeek(in: context, now: now)
        let previews = day.orderedExercises.map { planned -> ExercisePreview in
            let resolution = ProgramStore.resolve(planned, catalog: catalog, profile: profile)
            let exercise = exercises.first { $0.slug == resolution.slug }
            let rx = WorkoutService.prescription(for: planned, slug: resolution.slug, exercise: exercise, in: context)
            let sets = deload ? DeloadAdvisor.deloadSets(planned.sets) : planned.sets
            let primary = Set(exercise?.primaryMuscles ?? [])
            let warmup = exercise?.mechanic == .compound && !primary.isSubset(of: warmed)
            warmed.formUnion(primary)
            estimateItems.append(SessionEstimate.Item(sets: sets, restSeconds: planned.restSeconds, hasWarmup: warmup))
            let original = exercises.first { $0.slug == planned.exerciseSlug }?.nameUk ?? planned.exerciseSlug
            let substitution: String? = resolution.replacedBecause.flatMap { reason in
                resolution.isFallback ? nil : String(localized: "замість «\(original)»: \(reason.text)")
            }
            return ExercisePreview(
                id: planned.id,
                name: exercise?.nameUk ?? resolution.slug,
                target: PrescriptionText.target(sets: sets, prescription: rx, isTimed: exercise?.progression == .timed),
                hint: deload ? String(localized: "Розвантаження: менше підходів, та сама вага") : previewHint(rx),
                last: rx.last.map(PrescriptionText.lastTime),
                kind: rx.kind,
                substitution: substitution
            )
        }
        return Plan(program: program, day: day, next: next, previews: previews, estimatedMinutes: SessionEstimate.minutes(estimateItems))
    }

    private static func previewHint(_ rx: Prescription) -> String? {
        switch rx.kind {
        case .increaseWeight: String(localized: "Додаємо вагу")
        case .stall: String(localized: "Застій — пропонуємо −10 %")
        case .calibrate: String(localized: "Підберемо вагу на першому підході")
        case .addReps: String(localized: "+1 повтор")
        case .repeatWeight, .fromBaseline, .extendHold: nil
        }
    }

    /// Program day index of the most recent finished workout of this program.
    static func lastDayIndex(days: [ProgramDay], sessions: [WorkoutSession]) -> Int? {
        for session in sessions {
            if let id = session.programDayID, let index = days.firstIndex(where: { $0.id == id }) {
                return index
            }
        }
        return nil
    }

    // MARK: Deload

    /// Accepting a deload moves the next block start one week ahead; until then workouts are lighter.
    static func isDeloadWeek(in context: ModelContext, now: Date = .now) -> Bool {
        guard let start = ProfileStore.profile(in: context)?.blockStartDate else { return false }
        return start > now
    }

    static func deloadEndDate(in context: ModelContext) -> Date? {
        guard isDeloadWeek(in: context) else { return nil }
        return ProfileStore.profile(in: context)?.blockStartDate
    }

    static func acceptDeload(in context: ModelContext, now: Date = .now) {
        ProfileStore.profile(in: context)?.blockStartDate = Calendar.current.date(byAdding: .day, value: 7, to: now)
        try? context.save()
    }

    static func postponeDeload(in context: ModelContext, now: Date = .now) {
        // Ask again in two weeks.
        let back = Calendar.current.date(byAdding: .day, value: -(DeloadAdvisor.weeksBetweenDeloads * 7 - 14), to: now)
        ProfileStore.profile(in: context)?.blockStartDate = back
        try? context.save()
    }

    static func deloadReason(in context: ModelContext, now: Date = .now) -> DeloadAdvisor.Reason? {
        guard !isDeloadWeek(in: context, now: now), let program = ProgramStore.activeProgram(in: context) else { return nil }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let catalog = ProgramStore.catalog(exercises)
        let profile = ProfileStore.snapshot(in: context)
        var stalled = 0
        for day in program.orderedDays {
            for planned in day.orderedExercises {
                let slug = ProgramStore.resolve(planned, catalog: catalog, profile: profile).slug
                let exercise = exercises.first { $0.slug == slug }
                guard exercise?.mechanic == .compound else { continue }
                if WorkoutService.prescription(for: planned, slug: slug, exercise: exercise, in: context).kind == .stall {
                    stalled += 1
                }
            }
        }
        return DeloadAdvisor.reason(blockStart: ProfileStore.profile(in: context)?.blockStartDate, now: now, stalledCompoundLifts: stalled)
    }

    // MARK: Week

    static func weekProgress(in context: ModelContext, now: Date = .now) -> (done: Int, planned: Int, streak: Int) {
        let dates = WorkoutService.finishedSessions(in: context).map(\.startedAt)
        let planned = ProfileStore.snapshot(in: context).sessionsPerWeek
        return (
            TrainingSchedule.workoutsInWeek(of: now, workoutDates: dates),
            planned,
            TrainingSchedule.weekStreak(workoutDates: dates, target: planned, now: now)
        )
    }
}

/// Short evidence-based tips, one per day.
enum DailyTips {
    static let all: [LocalizedStringResource] = [
        "Сон 7–9 годин — найкращий «препарат» для росту м'язів.",
        "Білок краще розподілити на 3–5 прийомів їжі по 25–40 г.",
        "Записуй кожен підхід: прогрес видно лише тоді, коли його вимірюєш.",
        "Ріст м'язів — це прогресивне навантаження: трохи більше ваги або повторів, ніж минулого разу.",
        "Зважуйся зранку після туалету, до їжі — так коливання ваги менші.",
        "Важить тренд ваги за тиждень, а не цифра за один день.",
        "Креатин моногідрат 3–5 г на день — одна з найкраще досліджених добавок. Порадься з лікарем.",
        "Розминка — 5–10 хвилин легкої активності і кілька розминочних підходів перед базовими вправами.",
        "1–2 повтори в запасі (RIR) дають майже той самий ріст, що й відмова, але з меншою втомою.",
        "Якщо апетиту немає — пий калорії: молоко, кефір, смузі з бананом і арахісовою пастою.",
        "Техніка важливіша за вагу на штанзі. Знімай себе на відео час від часу.",
        "Біль у суглобі під час вправи — сигнал зупинитися і замінити вправу.",
        "Між тренуваннями однієї групи м'язів дай 48–72 години на відновлення.",
        "Вода: близько 35 мл на кг ваги, у день тренування — більше.",
        "Перший місяць сила росте швидше за м'язи — це нормально, нервова система вчиться.",
        "Застій? Перевір сон, калорії і білок, перш ніж міняти програму.",
        "Розвантажувальний тиждень кожні 6–8 тижнів допомагає продовжувати прогрес.",
        "Їжа до тренування за 1–3 години: вуглеводи + трохи білка.",
        "Після тренування немає «вікна в 30 хвилин» — важить загальний білок за день.",
        "Фото прогресу раз на 2–4 тижні при однаковому освітленні — краще за дзеркало."
    ]

    static func tip(for date: Date = .now, calendar: Calendar = .current) -> LocalizedStringResource {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
