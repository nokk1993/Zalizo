import Foundation
import SwiftData
import ZalizoCore

/// Export/import of all user data (JSON, versioned) and CSV of workouts.
@MainActor
enum BackupService {
    enum ImportMode {
        /// Delete everything, then restore the file.
        case replaceAll
        /// Keep current data and add what is missing (matched by id).
        case merge
    }

    enum BackupError: LocalizedError {
        case notABackup
        case newerVersion(Int)
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .notABackup: String(localized: "Це не файл резервної копії «Залізо».")
            case .newerVersion(let version): String(localized: "Файл створено новішою версією додатку (схема \(version)). Онови додаток і спробуй ще раз.")
            case .unreadable(let details): String(localized: "Не вдалося прочитати файл: \(details)")
            }
        }
    }

    struct ImportSummary {
        var workouts = 0
        var weights = 0
        var photos = 0
    }

    // MARK: Export

    static func makeBackup(in context: ModelContext, includePhotos: Bool, now: Date = .now) -> BackupFile {
        var file = BackupFile(exportedAt: now, appVersion: AppInfo.versionText, includesPhotos: includePhotos)
        func all<T: PersistentModel>(_ type: T.Type) -> [T] { (try? context.fetch(FetchDescriptor<T>())) ?? [] }

        if let p = all(UserProfile.self).first {
            file.profile = .init(
                id: p.id, createdAt: p.createdAt, onboardingCompleted: p.onboardingCompleted, sex: p.sexRaw, birthDate: p.birthDate,
                heightCm: p.heightCm, experience: p.experienceRaw, goal: p.goalRaw, trainingWeekdays: p.trainingWeekdays,
                sessionMinutes: p.sessionMinutes, activity: p.activityRaw, equipment: p.equipmentRaw, dumbbellMaxKg: p.dumbbellMaxKg,
                hasMicroPlates: p.hasMicroPlates, limitations: p.limitationsRaw, dietExclusions: p.dietExclusionsRaw,
                mealsPerDay: p.mealsPerDay, budget: p.budgetRaw, targetWeightKg: p.targetWeightKg, bodyFatPercent: p.bodyFatPercent,
                surplusPercentOverride: p.surplusPercentOverride, proteinPerKg: p.proteinPerKg, fatPerKg: p.fatPerKg,
                calorieAdjustmentKcal: p.calorieAdjustmentKcal, trainingDayCarbBoostKcal: p.trainingDayCarbBoostKcal,
                activeProgramID: p.activeProgramID, blockStartDate: p.blockStartDate
            )
        }
        if let s = all(AppSettings.self).first {
            file.settings = .init(
                barbellStepKg: s.barbellStepKg, dumbbellStepKg: s.dumbbellStepKg, machineStepKg: s.machineStepKg, barWeightKg: s.barWeightKg,
                platesKg: s.platesKg, defaultRestSeconds: s.defaultRestSeconds, autoStartRestTimer: s.autoStartRestTimer,
                soundEnabled: s.soundEnabled, hapticsEnabled: s.hapticsEnabled, theme: s.themeRaw, oneRMFormula: s.oneRMFormulaRaw,
                useWellnessCheck: s.useWellnessCheck, trainingReminderEnabled: s.trainingReminderEnabled,
                trainingReminderMinutes: s.trainingReminderMinutes, weighInReminderEnabled: s.weighInReminderEnabled,
                weighInReminderMinutes: s.weighInReminderMinutes, waterReminderEnabled: s.waterReminderEnabled,
                missedWorkoutReminderEnabled: s.missedWorkoutReminderEnabled, backupReminderEnabled: s.backupReminderEnabled,
                lastBackupAt: s.lastBackupAt
            )
        }
        file.baselines = all(StrengthBaseline.self).map { .init(id: $0.id, exerciseSlug: $0.exerciseSlug, weightKg: $0.weightKg, reps: $0.reps, date: $0.date) }
        file.weights = all(BodyWeightEntry.self).map { .init(id: $0.id, date: $0.date, weightKg: $0.weightKg) }
        file.measurements = all(BodyMeasurement.self).map { .init(id: $0.id, date: $0.date, kind: $0.kindRaw, valueCm: $0.valueCm) }
        file.photos = all(ProgressPhoto.self).map {
            .init(id: $0.id, date: $0.date, fileName: $0.fileName, angle: $0.angleRaw, note: $0.note,
                  imageData: includePhotos ? try? Data(contentsOf: PhotoStorage.url(for: $0.fileName, in: .progressPhotos)) : nil)
        }
        for e in all(Exercise.self) {
            let image = includePhotos ? e.customImageFileName.flatMap { try? Data(contentsOf: PhotoStorage.url(for: $0, in: .exercisePhotos)) } : nil
            if e.isCustom {
                file.customExercises.append(.init(
                    slug: e.slug, nameUk: e.nameUk, nameEn: e.nameEn, synonyms: e.synonyms, primaryMuscles: e.primaryMusclesRaw,
                    secondaryMuscles: e.secondaryMusclesRaw, equipment: e.equipmentRaw, mechanic: e.mechanicRaw, level: e.levelRaw,
                    region: e.regionRaw, progression: e.progressionRaw, techniqueSteps: e.techniqueSteps, commonMistakes: e.commonMistakes,
                    safetyTips: e.safetyTips, breathing: e.breathing, alternatives: e.alternatives, riskAreas: e.riskAreasRaw,
                    isFavorite: e.isFavorite, customImageFileName: e.customImageFileName, imageData: image
                ))
            } else if e.isFavorite || e.customImageFileName != nil {
                file.exerciseStates.append(.init(slug: e.slug, isFavorite: e.isFavorite, customImageFileName: e.customImageFileName, imageData: image))
            }
        }
        file.programs = all(Program.self).map { program in
            .init(id: program.id, name: program.name, summary: program.summary, audience: program.audience,
                  recommendedWeeks: program.recommendedWeeks, progressionNotes: program.progressionNotes, isBuiltIn: program.isBuiltIn,
                  seedSlug: program.seedSlug, createdAt: program.createdAt,
                  days: program.orderedDays.map { day in
                      .init(id: day.id, order: day.order, name: day.name, focus: day.focus, exercises: day.orderedExercises.map { item in
                          .init(id: item.id, order: item.order, exerciseSlug: item.exerciseSlug, sets: item.sets, repMin: item.repMin,
                                repMax: item.repMax, restSeconds: item.restSeconds, targetRIR: item.targetRIR,
                                progression: item.progressionRaw, incrementKg: item.incrementKg, note: item.note)
                      })
                  })
        }
        file.sessions = all(WorkoutSession.self).map { session in
            .init(id: session.id, startedAt: session.startedAt, endedAt: session.endedAt, isFinished: session.isFinished,
                  programDayID: session.programDayID, title: session.title, isDeload: session.isDeload,
                  wellnessSleep: session.wellnessSleep, wellnessFatigue: session.wellnessFatigue, wellnessSoreness: session.wellnessSoreness,
                  feeling: session.feeling, note: session.note,
                  exercises: session.orderedExercises.map { performed in
                      .init(id: performed.id, order: performed.order, exerciseSlug: performed.exerciseSlug, exerciseName: performed.exerciseName,
                            plannedSets: performed.plannedSets, repMin: performed.repMin, repMax: performed.repMax,
                            restSeconds: performed.restSeconds, targetRIR: performed.targetRIR, isSkipped: performed.isSkipped,
                            note: performed.note,
                            sets: performed.orderedSets.map { set in
                                .init(id: set.id, order: set.order, weightKg: set.weightKg, reps: set.reps, durationSeconds: set.durationSeconds,
                                      rir: set.rir, isWarmup: set.isWarmup, isCompleted: set.isCompleted, completedAt: set.completedAt, note: set.note)
                            })
                  })
        }
        file.records = all(PersonalRecord.self).map {
            .init(id: $0.id, exerciseSlug: $0.exerciseSlug, kind: $0.kindRaw, repTarget: $0.repTarget, value: $0.value,
                  weightKg: $0.weightKg, reps: $0.reps, date: $0.date, sessionID: $0.sessionID)
        }
        file.goals = all(Goal.self).map {
            .init(id: $0.id, kind: $0.kindRaw, title: $0.title, startValue: $0.startValue, targetValue: $0.targetValue,
                  exerciseSlug: $0.exerciseSlug, measurementKind: $0.measurementKindRaw, deadline: $0.deadline,
                  createdAt: $0.createdAt, achievedAt: $0.achievedAt)
        }
        file.achievements = all(Achievement.self).map { .init(key: $0.key, unlockedAt: $0.unlockedAt) }
        file.nutritionLogs = all(NutritionLog.self).map { log in
            .init(id: log.id, day: log.day, waterMl: log.waterMl, entries: log.entries.map {
                .init(id: $0.id, time: $0.time, name: $0.name, grams: $0.grams, kcal: $0.kcal, protein: $0.protein, fat: $0.fat, carbs: $0.carbs)
            })
        }
        file.calorieAdjustments = all(CalorieAdjustment.self).map {
            .init(id: $0.id, date: $0.date, deltaKcal: $0.deltaKcal, weeklyGainPercent: $0.weeklyGainPercent, accepted: $0.accepted)
        }
        return file
    }

    /// Writes the backup JSON to a temporary file for sharing / saving to Files.
    static func exportFile(in context: ModelContext, includePhotos: Bool) throws -> URL {
        let data = try BackupCodec.encode(makeBackup(in: context, includePhotos: includePhotos))
        let url = URL.temporaryDirectory.appending(path: BackupCodec.fileName())
        try data.write(to: url, options: .atomic)
        ProfileStore.settings(in: context)?.lastBackupAt = .now
        try? context.save()
        return url
    }

    static func exportCSV(in context: ModelContext) throws -> URL {
        let csv = CSVExport.workouts(makeBackup(in: context, includePhotos: false).sessions)
        let url = URL.temporaryDirectory.appending(path: BackupCodec.fileName().replacingOccurrences(of: "backup", with: "workouts").replacingOccurrences(of: ".json", with: ".csv"))
        // UTF-8 BOM so Excel shows Cyrillic correctly.
        try (Data([0xEF, 0xBB, 0xBF]) + Data(csv.utf8)).write(to: url, options: .atomic)
        return url
    }

    // MARK: Import

    static func decode(_ data: Data) throws -> BackupFile {
        do {
            return try BackupCodec.decode(data)
        } catch BackupCodec.DecodeError.notABackup {
            throw BackupError.notABackup
        } catch BackupCodec.DecodeError.unsupportedVersion(let version) {
            throw BackupError.newerVersion(version)
        } catch {
            throw BackupError.unreadable(error.localizedDescription)
        }
    }

    @discardableResult
    static func restore(_ file: BackupFile, mode: ImportMode, in context: ModelContext) throws -> ImportSummary {
        if mode == .replaceAll {
            DataReset.resetAll(in: context)
        }
        func existingIDs<T: PersistentModel>(_ type: T.Type, _ id: (T) -> UUID) -> Set<UUID> {
            Set(((try? context.fetch(FetchDescriptor<T>())) ?? []).map(id))
        }
        var summary = ImportSummary()

        if let dto = file.profile, let profile = ProfileStore.profile(in: context), mode == .replaceAll {
            profile.id = dto.id
            profile.createdAt = dto.createdAt
            profile.onboardingCompleted = dto.onboardingCompleted
            profile.onboardingStep = dto.onboardingCompleted ? OnboardingStep.summary.rawValue : 0
            profile.sexRaw = dto.sex
            profile.birthDate = dto.birthDate
            profile.heightCm = dto.heightCm
            profile.experienceRaw = dto.experience
            profile.goalRaw = dto.goal
            profile.trainingWeekdays = dto.trainingWeekdays
            profile.sessionMinutes = dto.sessionMinutes
            profile.activityRaw = dto.activity
            profile.equipmentRaw = dto.equipment
            profile.dumbbellMaxKg = dto.dumbbellMaxKg
            profile.hasMicroPlates = dto.hasMicroPlates
            profile.limitationsRaw = dto.limitations
            profile.dietExclusionsRaw = dto.dietExclusions
            profile.mealsPerDay = dto.mealsPerDay
            profile.budgetRaw = dto.budget
            profile.targetWeightKg = dto.targetWeightKg
            profile.bodyFatPercent = dto.bodyFatPercent
            profile.surplusPercentOverride = dto.surplusPercentOverride
            profile.proteinPerKg = dto.proteinPerKg
            profile.fatPerKg = dto.fatPerKg
            profile.calorieAdjustmentKcal = dto.calorieAdjustmentKcal
            profile.trainingDayCarbBoostKcal = dto.trainingDayCarbBoostKcal
            profile.activeProgramID = dto.activeProgramID
            profile.blockStartDate = dto.blockStartDate
        }
        if let dto = file.settings, let settings = ProfileStore.settings(in: context), mode == .replaceAll {
            settings.barbellStepKg = dto.barbellStepKg
            settings.dumbbellStepKg = dto.dumbbellStepKg
            settings.machineStepKg = dto.machineStepKg
            settings.barWeightKg = dto.barWeightKg
            settings.platesKg = dto.platesKg
            settings.defaultRestSeconds = dto.defaultRestSeconds
            settings.autoStartRestTimer = dto.autoStartRestTimer
            settings.soundEnabled = dto.soundEnabled
            settings.hapticsEnabled = dto.hapticsEnabled
            settings.themeRaw = dto.theme
            settings.oneRMFormulaRaw = dto.oneRMFormula
            settings.useWellnessCheck = dto.useWellnessCheck
            settings.trainingReminderEnabled = dto.trainingReminderEnabled
            settings.trainingReminderMinutes = dto.trainingReminderMinutes
            settings.weighInReminderEnabled = dto.weighInReminderEnabled
            settings.weighInReminderMinutes = dto.weighInReminderMinutes
            settings.waterReminderEnabled = dto.waterReminderEnabled
            settings.missedWorkoutReminderEnabled = dto.missedWorkoutReminderEnabled
            settings.backupReminderEnabled = dto.backupReminderEnabled
            settings.lastBackupAt = dto.lastBackupAt
        }

        let baselineIDs = existingIDs(StrengthBaseline.self, \.id)
        for dto in file.baselines where !baselineIDs.contains(dto.id) {
            let item = StrengthBaseline(exerciseSlug: dto.exerciseSlug, weightKg: dto.weightKg, reps: dto.reps, date: dto.date)
            item.id = dto.id
            context.insert(item)
        }
        let weightIDs = existingIDs(BodyWeightEntry.self, \.id)
        for dto in file.weights where !weightIDs.contains(dto.id) {
            let item = BodyWeightEntry(date: dto.date, weightKg: dto.weightKg)
            item.id = dto.id
            context.insert(item)
            summary.weights += 1
        }
        let measurementIDs = existingIDs(BodyMeasurement.self, \.id)
        for dto in file.measurements where !measurementIDs.contains(dto.id) {
            let item = BodyMeasurement(date: dto.date, kind: MeasurementKind(rawValue: dto.kind) ?? .waist, valueCm: dto.valueCm)
            item.kindRaw = dto.kind
            item.id = dto.id
            context.insert(item)
        }
        let photoIDs = existingIDs(ProgressPhoto.self, \.id)
        for dto in file.photos where !photoIDs.contains(dto.id) {
            var fileName = dto.fileName
            if let data = dto.imageData {
                fileName = (try? PhotoStorage.save(data, in: .progressPhotos)) ?? dto.fileName
            }
            let item = ProgressPhoto(date: dto.date, fileName: fileName, angle: PhotoAngle(rawValue: dto.angle) ?? .front, note: dto.note)
            item.id = dto.id
            context.insert(item)
            summary.photos += 1
        }

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for dto in file.customExercises where !exercises.contains(where: { $0.slug == dto.slug }) {
            let item = Exercise(slug: dto.slug, nameUk: dto.nameUk)
            item.nameEn = dto.nameEn
            item.synonyms = dto.synonyms
            item.primaryMusclesRaw = dto.primaryMuscles
            item.secondaryMusclesRaw = dto.secondaryMuscles
            item.equipmentRaw = dto.equipment
            item.mechanicRaw = dto.mechanic
            item.levelRaw = dto.level
            item.regionRaw = dto.region
            item.progressionRaw = dto.progression
            item.techniqueSteps = dto.techniqueSteps
            item.commonMistakes = dto.commonMistakes
            item.safetyTips = dto.safetyTips
            item.breathing = dto.breathing
            item.alternatives = dto.alternatives
            item.riskAreasRaw = dto.riskAreas
            item.isFavorite = dto.isFavorite
            item.isCustom = true
            item.userModified = true
            item.customImageFileName = dto.imageData.flatMap { try? PhotoStorage.save($0, in: .exercisePhotos) } ?? dto.customImageFileName
            context.insert(item)
        }
        for dto in file.exerciseStates {
            guard let exercise = exercises.first(where: { $0.slug == dto.slug }) else { continue }
            exercise.isFavorite = exercise.isFavorite || dto.isFavorite
            if exercise.customImageFileName == nil {
                exercise.customImageFileName = dto.imageData.flatMap { try? PhotoStorage.save($0, in: .exercisePhotos) } ?? dto.customImageFileName
            }
        }

        // Programs: on replace, drop the freshly seeded built-ins so the user's (possibly edited) versions come back.
        if mode == .replaceAll, !file.programs.isEmpty {
            for program in ProgramStore.programs(in: context) {
                context.delete(program)
            }
        }
        let programIDs = mode == .replaceAll ? [] : existingIDs(Program.self, \.id)
        for dto in file.programs where !programIDs.contains(dto.id) {
            let program = Program(name: dto.name)
            program.id = dto.id
            program.summary = dto.summary
            program.audience = dto.audience
            program.recommendedWeeks = dto.recommendedWeeks
            program.progressionNotes = dto.progressionNotes
            program.isBuiltIn = dto.isBuiltIn
            program.seedSlug = dto.seedSlug
            program.createdAt = dto.createdAt
            program.days = dto.days.map { dayDTO in
                let day = ProgramDay(order: dayDTO.order, name: dayDTO.name, focus: dayDTO.focus)
                day.id = dayDTO.id
                day.exercises = dayDTO.exercises.map { item in
                    let planned = PlannedExercise(order: item.order, exerciseSlug: item.exerciseSlug, sets: item.sets,
                                                  repMin: item.repMin, repMax: item.repMax, restSeconds: item.restSeconds)
                    planned.id = item.id
                    planned.targetRIR = item.targetRIR
                    planned.progressionRaw = item.progression
                    planned.incrementKg = item.incrementKg
                    planned.note = item.note
                    return planned
                }
                return day
            }
            context.insert(program)
        }

        let sessionIDs = existingIDs(WorkoutSession.self, \.id)
        for dto in file.sessions where !sessionIDs.contains(dto.id) {
            let session = WorkoutSession(startedAt: dto.startedAt, title: dto.title)
            session.id = dto.id
            session.endedAt = dto.endedAt
            session.isFinished = dto.isFinished
            session.programDayID = dto.programDayID
            session.isDeload = dto.isDeload
            session.wellnessSleep = dto.wellnessSleep
            session.wellnessFatigue = dto.wellnessFatigue
            session.wellnessSoreness = dto.wellnessSoreness
            session.feeling = dto.feeling
            session.note = dto.note
            session.exercises = dto.exercises.map { item in
                let performed = PerformedExercise(order: item.order, exerciseSlug: item.exerciseSlug, exerciseName: item.exerciseName)
                performed.id = item.id
                performed.plannedSets = item.plannedSets
                performed.repMin = item.repMin
                performed.repMax = item.repMax
                performed.restSeconds = item.restSeconds
                performed.targetRIR = item.targetRIR
                performed.isSkipped = item.isSkipped
                performed.note = item.note
                performed.sets = item.sets.map { setDTO in
                    let set = SetEntry(order: setDTO.order, weightKg: setDTO.weightKg, reps: setDTO.reps, isWarmup: setDTO.isWarmup)
                    set.id = setDTO.id
                    set.durationSeconds = setDTO.durationSeconds
                    set.rir = setDTO.rir
                    set.isCompleted = setDTO.isCompleted
                    set.completedAt = setDTO.completedAt
                    set.note = setDTO.note
                    return set
                }
                return performed
            }
            context.insert(session)
            summary.workouts += 1
        }

        let recordIDs = existingIDs(PersonalRecord.self, \.id)
        for dto in file.records where !recordIDs.contains(dto.id) {
            let record = PersonalRecord(exerciseSlug: dto.exerciseSlug, kind: RecordKind(rawValue: dto.kind) ?? .maxWeight,
                                        value: dto.value, weightKg: dto.weightKg, reps: dto.reps, date: dto.date)
            record.kindRaw = dto.kind
            record.id = dto.id
            record.repTarget = dto.repTarget
            record.sessionID = dto.sessionID
            context.insert(record)
        }
        let goalIDs = existingIDs(Goal.self, \.id)
        for dto in file.goals where !goalIDs.contains(dto.id) {
            let goal = Goal(kind: GoalKind(rawValue: dto.kind) ?? .bodyWeight, title: dto.title, startValue: dto.startValue, targetValue: dto.targetValue)
            goal.kindRaw = dto.kind
            goal.id = dto.id
            goal.exerciseSlug = dto.exerciseSlug
            goal.measurementKindRaw = dto.measurementKind
            goal.deadline = dto.deadline
            goal.createdAt = dto.createdAt
            goal.achievedAt = dto.achievedAt
            context.insert(goal)
        }
        let achievementKeys = Set(((try? context.fetch(FetchDescriptor<Achievement>())) ?? []).map(\.key))
        for dto in file.achievements where !achievementKeys.contains(dto.key) {
            context.insert(Achievement(key: dto.key, unlockedAt: dto.unlockedAt))
        }
        let logIDs = existingIDs(NutritionLog.self, \.id)
        for dto in file.nutritionLogs where !logIDs.contains(dto.id) {
            let log = NutritionLog(day: dto.day)
            log.id = dto.id
            log.waterMl = dto.waterMl
            log.entries = dto.entries.map { item in
                let entry = FoodEntry(name: item.name, kcal: item.kcal, protein: item.protein, fat: item.fat, carbs: item.carbs, grams: item.grams)
                entry.id = item.id
                entry.time = item.time
                return entry
            }
            context.insert(log)
        }
        let adjustmentIDs = existingIDs(CalorieAdjustment.self, \.id)
        for dto in file.calorieAdjustments where !adjustmentIDs.contains(dto.id) {
            let item = CalorieAdjustment(date: dto.date, deltaKcal: dto.deltaKcal, weeklyGainPercent: dto.weeklyGainPercent, accepted: dto.accepted)
            item.id = dto.id
            context.insert(item)
        }

        try context.save()
        return summary
    }
}
