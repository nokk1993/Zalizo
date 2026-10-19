import AudioToolbox
import Foundation
import Observation
import SwiftData
import ZalizoCore

/// Live state of a running workout. Every change is saved immediately, so a crash or reboot loses nothing.
@MainActor
@Observable
final class WorkoutModel {
    struct RecordBanner: Identifiable, Equatable {
        let id = UUID()
        let exerciseName: String
        let text: String
    }

    struct CalibrationRequest: Identifiable {
        let id = UUID()
        let performedID: UUID
        let setID: UUID
    }

    let session: WorkoutSession
    let sessionID: UUID
    private let context: ModelContext

    var restTimer: RestTimer?
    var restNextSetText = ""
    var recordBanner: RecordBanner?
    var calibration: CalibrationRequest?
    /// All records broken during this workout (for the summary).
    private(set) var records: [RecordBanner] = []

    private(set) var prescriptions: [UUID: Prescription] = [:]
    @ObservationIgnored private var bests: [String: ExerciseBests] = [:]
    let loadSettings: LoadSettings
    private let appSettings: AppSettings?
    @ObservationIgnored private var restTicker: Task<Void, Never>?

    init(session: WorkoutSession, context: ModelContext) {
        self.session = session
        self.sessionID = session.id
        self.context = context
        self.loadSettings = WorkoutService.loadSettings(in: context)
        self.appSettings = ProfileStore.settings(in: context)
        Haptics.isEnabled = appSettings?.hapticsEnabled ?? true
        refreshPrescriptions()
    }

    var formula: OneRMFormula { appSettings?.oneRMFormula ?? .epley }

    func refreshPrescriptions() {
        for performed in session.exercises {
            let exercise = WorkoutService.exercise(performed.exerciseSlug, in: context)
            prescriptions[performed.id] = WorkoutService.prescription(for: performed, exercise: exercise, sessionID: session.id, in: context)
            if bests[performed.exerciseSlug] == nil {
                var value = WorkoutService.bests(for: performed.exerciseSlug, excluding: session.id, in: context, formula: formula)
                for set in performed.workingSets {
                    _ = value.register(PerformedSet(weight: set.weightKg, reps: set.reps), formula: formula)
                }
                bests[performed.exerciseSlug] = value
            }
        }
    }

    func exercise(for performed: PerformedExercise) -> Exercise? {
        WorkoutService.exercise(performed.exerciseSlug, in: context)
    }

    func plan(for performed: PerformedExercise) -> ExercisePlan {
        WorkoutService.plan(for: performed, exercise: exercise(for: performed), settings: loadSettings)
    }

    func weightStep(for performed: PerformedExercise) -> Double {
        ProgressionEngine.roundingStep(for: plan(for: performed), settings: loadSettings)
    }

    // MARK: Sets

    func complete(_ set: SetEntry, in performed: PerformedExercise) {
        set.isCompleted = true
        set.completedAt = .now
        save()
        Haptics.setCompleted()

        if !set.isWarmup {
            detectRecords(set, in: performed)
            if prescriptions[performed.id]?.kind == .calibrate,
               performed.workingSets.count == 1,
               performed.orderedSets.contains(where: { !$0.isWarmup && !$0.isCompleted }) {
                calibration = CalibrationRequest(performedID: performed.id, setID: set.id)
            }
        }
        if appSettings?.autoStartRestTimer ?? true {
            startRest(seconds: set.isWarmup ? min(60, performed.restSeconds) : performed.restSeconds, after: performed)
        } else {
            updateLiveActivity()
        }
    }

    func uncomplete(_ set: SetEntry) {
        set.isCompleted = false
        set.completedAt = nil
        save()
    }

    /// Calibration answer: reps in reserve after the first light set → weight for the remaining sets.
    func applyCalibration(rir: Int) {
        guard let request = calibration,
              let performed = session.exercises.first(where: { $0.id == request.performedID }),
              let set = performed.sets.first(where: { $0.id == request.setID }) else { return }
        set.rir = rir
        let next = Calibration.nextWeight(after: PerformedSet(weight: set.weightKg, reps: set.reps, rir: rir), plan: plan(for: performed), settings: loadSettings, formula: formula)
        for pending in performed.orderedSets where !pending.isWarmup && !pending.isCompleted {
            pending.weightKg = next
        }
        calibration = nil
        save()
    }

    func addSet(to performed: PerformedExercise) {
        let last = performed.orderedSets.last { !$0.isWarmup } ?? performed.orderedSets.last
        let order = (performed.sets.map(\.order).max() ?? -1) + 1
        let set = SetEntry(order: order, weightKg: last?.weightKg ?? 0, reps: last?.reps ?? performed.repMin)
        performed.sets.append(set)
        save()
    }

    func delete(_ set: SetEntry, from performed: PerformedExercise) {
        performed.sets.removeAll { $0.id == set.id }
        context.delete(set)
        save()
    }

    func toggleWarmup(_ set: SetEntry) {
        set.isWarmup.toggle()
        save()
    }

    func setRIR(_ rir: Int?, for set: SetEntry) {
        set.rir = rir
        save()
    }

    // MARK: Exercises

    func add(_ exercise: Exercise) {
        let performed = WorkoutService.add(exercise, to: session, in: context)
        prescriptions[performed.id] = WorkoutService.prescription(for: performed, exercise: exercise, sessionID: session.id, in: context)
        bests[exercise.slug] = WorkoutService.bests(for: exercise.slug, excluding: session.id, in: context, formula: formula)
    }

    func replace(_ performed: PerformedExercise, with exercise: Exercise) {
        WorkoutService.replace(performed, with: exercise, in: context)
        prescriptions[performed.id] = WorkoutService.prescription(for: performed, exercise: exercise, sessionID: session.id, in: context)
        bests[exercise.slug] = WorkoutService.bests(for: exercise.slug, excluding: session.id, in: context, formula: formula)
    }

    func toggleSkip(_ performed: PerformedExercise) {
        performed.isSkipped.toggle()
        save()
    }

    func move(_ performed: PerformedExercise, by offset: Int) {
        var ordered = session.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.id == performed.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        for (position, item) in ordered.enumerated() {
            item.order = position
        }
        save()
    }

    func remove(_ performed: PerformedExercise) {
        session.exercises.removeAll { $0.id == performed.id }
        context.delete(performed)
        save()
    }

    // MARK: Rest timer

    func startRest(seconds: Int, after performed: PerformedExercise) {
        restTimer = RestTimer(seconds: seconds)
        restNextSetText = nextSetDescription(after: performed)
        NotificationService.scheduleRestEnd(after: TimeInterval(seconds), nextSet: restNextSetText, sound: appSettings?.soundEnabled ?? true)
        Task { await NotificationService.requestAuthorizationIfNeeded() }
        startTicker()
        updateLiveActivity()
    }

    func addRest(seconds: Int = 30) {
        guard var timer = restTimer else { return }
        timer.add(seconds: seconds)
        restTimer = timer
        NotificationService.scheduleRestEnd(after: timer.remaining(), nextSet: restNextSetText, sound: appSettings?.soundEnabled ?? true)
        startTicker()
        updateLiveActivity()
    }

    func skipRest() {
        restTimer = nil
        restTicker?.cancel()
        NotificationService.cancelRestEnd()
        updateLiveActivity()
    }

    /// Lock screen / Dynamic Island state: rest countdown + next set.
    func updateLiveActivity() {
        let pending = session.orderedExercises.filter { !$0.isSkipped }
            .compactMap { item in item.orderedSets.first { !$0.isCompleted }.map { (item, $0) } }
            .first
        let done = session.exercises.reduce(0) { $0 + $1.workingSets.count }
        let total = session.exercises.filter { !$0.isSkipped }.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count }
        let state = RestActivityAttributes.ContentState(
            restEnd: restTimer?.endDate,
            exerciseName: pending?.0.exerciseName ?? session.title,
            nextSet: pending.map { "\($0.1.weightKg.kgText) кг × \($0.1.reps)" } ?? String(localized: "Усе виконано"),
            setsDone: done,
            setsTotal: total
        )
        LiveActivityService.start(title: session.title, startedAt: session.startedAt, state: state)
    }

    /// Wakes up when the rest ends while the app is in the foreground: vibration + sound.
    private func startTicker() {
        restTicker?.cancel()
        guard let timer = restTimer else { return }
        let remaining = timer.remaining()
        restTicker = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, let self else { return }
            self.restDidFinish()
        }
    }

    private func restDidFinish() {
        guard let timer = restTimer, timer.isFinished() else { return }
        restTimer = nil
        NotificationService.cancelRestEnd()
        updateLiveActivity()
        Haptics.restFinished()
        if appSettings?.soundEnabled ?? true {
            AudioServicesPlaySystemSound(1005)
        }
    }

    private func nextSetDescription(after performed: PerformedExercise) -> String {
        let ordered = session.orderedExercises.filter { !$0.isSkipped }
        let candidates = ordered.drop { $0.id != performed.id }
        for item in candidates {
            if let set = item.orderedSets.first(where: { !$0.isCompleted }) {
                return String(localized: "Далі: \(item.exerciseName) — \(set.weightKg.kgText) кг × \(set.reps)")
            }
        }
        for item in ordered {
            if let set = item.orderedSets.first(where: { !$0.isCompleted }) {
                return String(localized: "Далі: \(item.exerciseName) — \(set.weightKg.kgText) кг × \(set.reps)")
            }
        }
        return String(localized: "Усі підходи виконано — завершуй тренування")
    }

    // MARK: Records

    private func detectRecords(_ set: SetEntry, in performed: PerformedExercise) {
        var value = bests[performed.exerciseSlug] ?? ExerciseBests()
        let hadHistory = value != ExerciseBests()
        let hits = value.register(PerformedSet(weight: set.weightKg, reps: set.reps), formula: formula)
        bests[performed.exerciseSlug] = value
        guard hadHistory, let best = hits.first(where: { $0.kind == .estimatedOneRM }) ?? hits.first else { return }
        let text: String = switch best.kind {
        case .maxWeight: String(localized: "Рекорд ваги: \(best.value.kgText) кг")
        case .estimatedOneRM: String(localized: "Новий рекорд 1ПМ: \(best.value.kgText) кг")
        case .setVolume: String(localized: "Рекорд об'єму підходу: \(Int(best.value)) кг")
        case .repMax: String(localized: "Рекорд на \(best.repTarget) повт.: \(best.value.kgText) кг")
        }
        let banner = RecordBanner(exerciseName: performed.exerciseName, text: text)
        recordBanner = banner
        records.append(banner)
        Haptics.personalRecord()
    }

    // MARK: Finish

    var stats: WorkoutStats { WorkoutService.stats(for: session) }

    var previousStats: WorkoutStats? {
        WorkoutService.previousSession(like: session, in: context).map { WorkoutService.stats(for: $0) }
    }

    var hasCompletedSets: Bool {
        session.exercises.contains { $0.sets.contains(where: \.isCompleted) }
    }

    func finish(feeling: Int?, note: String) {
        skipRest()
        LiveActivityService.end()
        WorkoutService.finish(session, feeling: feeling, note: note, in: context)
    }

    func discard() {
        skipRest()
        LiveActivityService.end()
        WorkoutService.discard(session, in: context)
    }

    func dropOneSet() {
        WorkoutService.dropOneSet(in: session, context: context)
    }

    func reduceWeight() {
        WorkoutService.reduceWeight(in: session, context: context)
    }

    func saveWellness(sleep: Int, energy: Int, soreness: Int) {
        session.wellnessSleep = sleep
        session.wellnessFatigue = energy
        session.wellnessSoreness = soreness
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            Log.data.error("Workout save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
