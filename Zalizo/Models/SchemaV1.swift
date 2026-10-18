import Foundation
import SwiftData
import ZalizoCore

// Schema v1. The full data model is defined up front so that the first build on the phone
// already stores data in its final shape. Any later change goes into SchemaV2 + a migration
// stage in `ZalizoMigrationPlan` — never edit these models in place after release.
//
// Enum-typed values are stored as raw strings (with typed accessors) so that adding enum cases
// never breaks decoding of existing stores. Cross-entity references to exercises use the stable
// `slug` string rather than relationships: seeds, custom exercises and backups stay decoupled.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self, AppSettings.self, StrengthBaseline.self,
            BodyWeightEntry.self, BodyMeasurement.self, ProgressPhoto.self,
            Exercise.self,
            Program.self, ProgramDay.self, PlannedExercise.self,
            WorkoutSession.self, PerformedExercise.self, SetEntry.self,
            PersonalRecord.self, Goal.self, Achievement.self,
            NutritionLog.self, FoodEntry.self, CalorieAdjustment.self
        ]
    }

    // MARK: - Profile

    @Model
    final class UserProfile {
        var id = UUID()
        var createdAt = Date.now
        /// Index of the last onboarding step the user reached (resume support).
        var onboardingStep = 0
        var onboardingCompleted = false

        var sexRaw = Defaults.sex.rawValue
        var birthDate: Date?
        var heightCm = Defaults.heightCm
        var experienceRaw = Defaults.experience.rawValue
        var goalRaw = Defaults.goal.rawValue
        /// ISO weekdays 1…7
        var trainingWeekdays: [Int] = Defaults.trainingDays.map(\.rawValue)
        var sessionMinutes = Defaults.sessionMinutes
        var activityRaw = Defaults.activity.rawValue

        var equipmentRaw: [String] = Defaults.equipment.map(\.rawValue)
        var dumbbellMaxKg = Defaults.dumbbellMaxKg
        var hasMicroPlates = true
        var limitationsRaw: [String] = []

        var dietExclusionsRaw: [String] = []
        var mealsPerDay = Defaults.mealsPerDay
        var budgetRaw = Defaults.budget.rawValue

        var targetWeightKg: Double?
        var bodyFatPercent: Double?
        /// Overrides; nil → use defaults derived from experience.
        var surplusPercentOverride: Double?
        var proteinPerKg = Defaults.proteinPerKg
        var fatPerKg = Defaults.fatPerKg
        /// Sum of confirmed adaptive calorie corrections.
        var calorieAdjustmentKcal = 0
        var trainingDayCarbBoostKcal = 0

        var activeProgramID: UUID?
        /// When the current training block started (deload scheduling).
        var blockStartDate: Date?

        init() {}

        var sex: Sex {
            get { Sex(rawValue: sexRaw) ?? Defaults.sex }
            set { sexRaw = newValue.rawValue }
        }
        var experience: ExperienceLevel {
            get { ExperienceLevel(rawValue: experienceRaw) ?? Defaults.experience }
            set { experienceRaw = newValue.rawValue }
        }
        var goal: TrainingGoal {
            get { TrainingGoal(rawValue: goalRaw) ?? Defaults.goal }
            set { goalRaw = newValue.rawValue }
        }
        var activity: ActivityLevel {
            get { ActivityLevel(rawValue: activityRaw) ?? Defaults.activity }
            set { activityRaw = newValue.rawValue }
        }
        var budget: FoodBudget {
            get { FoodBudget(rawValue: budgetRaw) ?? Defaults.budget }
            set { budgetRaw = newValue.rawValue }
        }
        var weekdays: [Weekday] {
            get { trainingWeekdays.compactMap(Weekday.init(rawValue:)).sorted() }
            set { trainingWeekdays = newValue.sorted().map(\.rawValue) }
        }
        var equipment: Set<Equipment> {
            get { Set(equipmentRaw.compactMap(Equipment.init(rawValue:))) }
            set { equipmentRaw = newValue.map(\.rawValue).sorted() }
        }
        var limitations: Set<InjuryArea> {
            get { Set(limitationsRaw.compactMap(InjuryArea.init(rawValue:))) }
            set { limitationsRaw = newValue.map(\.rawValue).sorted() }
        }
        var dietExclusions: Set<DietExclusion> {
            get { Set(dietExclusionsRaw.compactMap(DietExclusion.init(rawValue:))) }
            set { dietExclusionsRaw = newValue.map(\.rawValue).sorted() }
        }
    }

    @Model
    final class AppSettings {
        var id = UUID()
        var barbellStepKg = Defaults.barbellStepKg
        var dumbbellStepKg = Defaults.dumbbellStepKg
        var machineStepKg = Defaults.machineStepKg
        var barWeightKg = Defaults.barWeightKg
        var platesKg: [Double] = Defaults.plates
        var defaultRestSeconds = Defaults.restSeconds
        var autoStartRestTimer = true
        var soundEnabled = true
        var hapticsEnabled = true
        var themeRaw = AppTheme.system.rawValue
        var oneRMFormulaRaw = OneRMFormula.epley.rawValue
        var useWellnessCheck = true

        var trainingReminderEnabled = false
        /// Minutes after midnight
        var trainingReminderMinutes = 17 * 60
        var weighInReminderEnabled = false
        var weighInReminderMinutes = 8 * 60
        var waterReminderEnabled = false
        var missedWorkoutReminderEnabled = false
        var backupReminderEnabled = true
        var lastBackupAt: Date?

        /// Seed versions already applied (seed never overwrites user edits).
        var exercisesSeedVersion = 0
        var programsSeedVersion = 0

        init() {}

        var theme: AppTheme {
            get { AppTheme(rawValue: themeRaw) ?? .system }
            set { themeRaw = newValue.rawValue }
        }
        var oneRMFormula: OneRMFormula {
            get { OneRMFormula(rawValue: oneRMFormulaRaw) ?? .epley }
            set { oneRMFormulaRaw = newValue.rawValue }
        }
    }

    /// Known lift entered in onboarding ("bench 70 kg × 10") — seeds working weights.
    @Model
    final class StrengthBaseline {
        var id = UUID()
        var exerciseSlug = ""
        var weightKg = 0.0
        var reps = 0
        var date = Date.now

        init(exerciseSlug: String, weightKg: Double, reps: Int, date: Date = .now) {
            self.exerciseSlug = exerciseSlug
            self.weightKg = weightKg
            self.reps = reps
            self.date = date
        }
    }

    // MARK: - Body

    @Model
    final class BodyWeightEntry {
        var id = UUID()
        var date = Date.now
        var weightKg = 0.0

        init(date: Date, weightKg: Double) {
            self.date = date
            self.weightKg = weightKg
        }
    }

    @Model
    final class BodyMeasurement {
        var id = UUID()
        var date = Date.now
        var kindRaw = MeasurementKind.waist.rawValue
        var valueCm = 0.0

        init(date: Date, kind: MeasurementKind, valueCm: Double) {
            self.date = date
            self.kindRaw = kind.rawValue
            self.valueCm = valueCm
        }

        var kind: MeasurementKind { MeasurementKind(rawValue: kindRaw) ?? .waist }
    }

    @Model
    final class ProgressPhoto {
        var id = UUID()
        var date = Date.now
        /// File name inside Documents/ProgressPhotos (never an absolute path: the container path changes).
        var fileName = ""
        var angleRaw = PhotoAngle.front.rawValue
        var note = ""

        init(date: Date, fileName: String, angle: PhotoAngle, note: String = "") {
            self.date = date
            self.fileName = fileName
            self.angleRaw = angle.rawValue
            self.note = note
        }

        var angle: PhotoAngle { PhotoAngle(rawValue: angleRaw) ?? .front }
    }

    // MARK: - Exercise library

    @Model
    final class Exercise {
        @Attribute(.unique) var slug = ""
        var nameUk = ""
        var nameEn = ""
        var synonyms: [String] = []
        var primaryMusclesRaw: [String] = []
        var secondaryMusclesRaw: [String] = []
        var equipmentRaw: [String] = []
        var mechanicRaw = ExerciseMechanic.compound.rawValue
        var levelRaw = ExerciseLevel.beginner.rawValue
        var regionRaw = BodyRegion.upper.rawValue
        var progressionRaw = ProgressionType.doubleProgression.rawValue
        var techniqueSteps: [String] = []
        var commonMistakes: [String] = []
        var safetyTips: [String] = []
        var breathing = ""
        var alternatives: [String] = []
        /// Injury areas this movement loads heavily (used to propose safer swaps).
        var riskAreasRaw: [String] = []
        /// Asset catalog image names (start, finish).
        var imageNames: [String] = []
        /// File name in Documents/ExercisePhotos — overrides bundled images.
        var customImageFileName: String?
        var isCustom = false
        var isFavorite = false
        /// Set when the user edits a seeded exercise: seed updates then leave it alone.
        var userModified = false
        var seedVersion = 0

        init(slug: String, nameUk: String) {
            self.slug = slug
            self.nameUk = nameUk
        }

        var primaryMuscles: [MuscleGroup] { primaryMusclesRaw.compactMap(MuscleGroup.init(rawValue:)) }
        var secondaryMuscles: [MuscleGroup] { secondaryMusclesRaw.compactMap(MuscleGroup.init(rawValue:)) }
        var equipment: [Equipment] { equipmentRaw.compactMap(Equipment.init(rawValue:)) }
        var mechanic: ExerciseMechanic { ExerciseMechanic(rawValue: mechanicRaw) ?? .compound }
        var level: ExerciseLevel { ExerciseLevel(rawValue: levelRaw) ?? .beginner }
        var region: BodyRegion { BodyRegion(rawValue: regionRaw) ?? .upper }
        var progression: ProgressionType { ProgressionType(rawValue: progressionRaw) ?? .doubleProgression }
        var riskAreas: [InjuryArea] { riskAreasRaw.compactMap(InjuryArea.init(rawValue:)) }
    }

    // MARK: - Programs

    @Model
    final class Program {
        var id = UUID()
        var name = ""
        var summary = ""
        var audience = ""
        var recommendedWeeks = 8
        var progressionNotes = ""
        var isBuiltIn = false
        /// Stable id of the seed this program came from (nil for user-created).
        var seedSlug: String?
        var createdAt = Date.now
        @Relationship(deleteRule: .cascade, inverse: \ProgramDay.program)
        var days: [ProgramDay] = []

        init(name: String) {
            self.name = name
        }

        var orderedDays: [ProgramDay] { days.sorted { $0.order < $1.order } }
    }

    @Model
    final class ProgramDay {
        var id = UUID()
        var order = 0
        var name = ""
        var focus = ""
        var program: Program?
        @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.day)
        var exercises: [PlannedExercise] = []

        init(order: Int, name: String, focus: String = "") {
            self.order = order
            self.name = name
            self.focus = focus
        }

        var orderedExercises: [PlannedExercise] { exercises.sorted { $0.order < $1.order } }
    }

    @Model
    final class PlannedExercise {
        var id = UUID()
        var order = 0
        var exerciseSlug = ""
        var sets = 3
        var repMin = 8
        var repMax = 12
        var restSeconds = Defaults.restSeconds
        var targetRIR = 2
        var progressionRaw = ProgressionType.doubleProgression.rawValue
        /// nil → derive from exercise region/equipment and settings.
        var incrementKg: Double?
        var note = ""
        var day: ProgramDay?

        init(order: Int, exerciseSlug: String, sets: Int, repMin: Int, repMax: Int, restSeconds: Int) {
            self.order = order
            self.exerciseSlug = exerciseSlug
            self.sets = sets
            self.repMin = repMin
            self.repMax = repMax
            self.restSeconds = restSeconds
        }

        var progression: ProgressionType { ProgressionType(rawValue: progressionRaw) ?? .doubleProgression }
    }

    // MARK: - Workouts

    @Model
    final class WorkoutSession {
        var id = UUID()
        var startedAt = Date.now
        var endedAt: Date?
        var isFinished = false
        var programDayID: UUID?
        /// Snapshot of the day name — survives program edits/deletion.
        var title = ""
        var isDeload = false
        var wellnessSleep: Int?
        var wellnessFatigue: Int?
        var wellnessSoreness: Int?
        /// Post-workout feeling 1–5
        var feeling: Int?
        var note = ""
        @Relationship(deleteRule: .cascade, inverse: \PerformedExercise.session)
        var exercises: [PerformedExercise] = []

        init(startedAt: Date = .now, title: String) {
            self.startedAt = startedAt
            self.title = title
        }

        var orderedExercises: [PerformedExercise] { exercises.sorted { $0.order < $1.order } }
        var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
    }

    @Model
    final class PerformedExercise {
        var id = UUID()
        var order = 0
        var exerciseSlug = ""
        var exerciseName = ""
        // Plan snapshot at the time of the workout (progression reads these).
        var plannedSets = 3
        var repMin = 8
        var repMax = 12
        var restSeconds = Defaults.restSeconds
        var targetRIR = 2
        var isSkipped = false
        var note = ""
        var session: WorkoutSession?
        @Relationship(deleteRule: .cascade, inverse: \SetEntry.exercise)
        var sets: [SetEntry] = []

        init(order: Int, exerciseSlug: String, exerciseName: String) {
            self.order = order
            self.exerciseSlug = exerciseSlug
            self.exerciseName = exerciseName
        }

        var orderedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }
        var workingSets: [SetEntry] { orderedSets.filter { !$0.isWarmup && $0.isCompleted } }
    }

    @Model
    final class SetEntry {
        var id = UUID()
        var order = 0
        var weightKg = 0.0
        var reps = 0
        var durationSeconds: Int?
        var rir: Int?
        var isWarmup = false
        var isCompleted = false
        var completedAt: Date?
        var note = ""
        var exercise: PerformedExercise?

        init(order: Int, weightKg: Double, reps: Int, isWarmup: Bool = false) {
            self.order = order
            self.weightKg = weightKg
            self.reps = reps
            self.isWarmup = isWarmup
        }
    }

    // MARK: - Records, goals, achievements

    @Model
    final class PersonalRecord {
        var id = UUID()
        var exerciseSlug = ""
        var kindRaw = RecordKind.maxWeight.rawValue
        /// For repMax: the rep count (1, 3, 5, 8, 10). 0 otherwise.
        var repTarget = 0
        var value = 0.0
        var weightKg = 0.0
        var reps = 0
        var date = Date.now
        var sessionID: UUID?

        init(exerciseSlug: String, kind: RecordKind, value: Double, weightKg: Double, reps: Int, date: Date) {
            self.exerciseSlug = exerciseSlug
            self.kindRaw = kind.rawValue
            self.value = value
            self.weightKg = weightKg
            self.reps = reps
            self.date = date
        }

        var kind: RecordKind { RecordKind(rawValue: kindRaw) ?? .maxWeight }
    }

    @Model
    final class Goal {
        var id = UUID()
        var kindRaw = GoalKind.bodyWeight.rawValue
        var title = ""
        var startValue = 0.0
        var targetValue = 0.0
        var exerciseSlug: String?
        var measurementKindRaw: String?
        var deadline: Date?
        var createdAt = Date.now
        var achievedAt: Date?

        init(kind: GoalKind, title: String, startValue: Double, targetValue: Double) {
            self.kindRaw = kind.rawValue
            self.title = title
            self.startValue = startValue
            self.targetValue = targetValue
        }

        var kind: GoalKind { GoalKind(rawValue: kindRaw) ?? .bodyWeight }
    }

    @Model
    final class Achievement {
        @Attribute(.unique) var key = ""
        var unlockedAt = Date.now

        init(key: String, unlockedAt: Date = .now) {
            self.key = key
            self.unlockedAt = unlockedAt
        }
    }

    // MARK: - Nutrition

    @Model
    final class NutritionLog {
        var id = UUID()
        /// Start of the local day.
        var day = Date.now
        var waterMl = 0
        @Relationship(deleteRule: .cascade, inverse: \FoodEntry.log)
        var entries: [FoodEntry] = []

        init(day: Date) {
            self.day = day
        }

        var kcal: Double { entries.reduce(0) { $0 + $1.kcal } }
        var protein: Double { entries.reduce(0) { $0 + $1.protein } }
        var fat: Double { entries.reduce(0) { $0 + $1.fat } }
        var carbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    }

    @Model
    final class FoodEntry {
        var id = UUID()
        var time = Date.now
        var name = ""
        var grams: Double?
        var kcal = 0.0
        var protein = 0.0
        var fat = 0.0
        var carbs = 0.0
        var log: NutritionLog?

        init(name: String, kcal: Double, protein: Double, fat: Double = 0, carbs: Double = 0, grams: Double? = nil) {
            self.name = name
            self.kcal = kcal
            self.protein = protein
            self.fat = fat
            self.carbs = carbs
            self.grams = grams
        }
    }

    /// History of proposed/confirmed adaptive calorie corrections.
    @Model
    final class CalorieAdjustment {
        var id = UUID()
        var date = Date.now
        var deltaKcal = 0
        var weeklyGainPercent = 0.0
        var accepted = false

        init(date: Date, deltaKcal: Int, weeklyGainPercent: Double, accepted: Bool) {
            self.date = date
            self.deltaKcal = deltaKcal
            self.weeklyGainPercent = weeklyGainPercent
            self.accepted = accepted
        }
    }
}

// Current-version aliases: the rest of the app refers to these names only.
typealias UserProfile = SchemaV1.UserProfile
typealias AppSettings = SchemaV1.AppSettings
typealias StrengthBaseline = SchemaV1.StrengthBaseline
typealias BodyWeightEntry = SchemaV1.BodyWeightEntry
typealias BodyMeasurement = SchemaV1.BodyMeasurement
typealias ProgressPhoto = SchemaV1.ProgressPhoto
typealias Exercise = SchemaV1.Exercise
typealias Program = SchemaV1.Program
typealias ProgramDay = SchemaV1.ProgramDay
typealias PlannedExercise = SchemaV1.PlannedExercise
typealias WorkoutSession = SchemaV1.WorkoutSession
typealias PerformedExercise = SchemaV1.PerformedExercise
typealias SetEntry = SchemaV1.SetEntry
typealias PersonalRecord = SchemaV1.PersonalRecord
typealias Goal = SchemaV1.Goal
typealias Achievement = SchemaV1.Achievement
typealias NutritionLog = SchemaV1.NutritionLog
typealias FoodEntry = SchemaV1.FoodEntry
typealias CalorieAdjustment = SchemaV1.CalorieAdjustment
