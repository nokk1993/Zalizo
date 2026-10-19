import Foundation

/// Versioned backup format. Bump `currentSchemaVersion` when fields change and keep decoding old files
/// (new fields must be optional or have defaults).
public struct BackupFile: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var includesPhotos: Bool

    public var profile: Profile?
    public var settings: Settings?
    public var baselines: [Baseline] = []
    public var weights: [Weight] = []
    public var measurements: [Measurement] = []
    public var photos: [Photo] = []
    /// User-created exercises (full definition).
    public var customExercises: [CustomExercise] = []
    /// Favourite flags and custom photos of seeded exercises.
    public var exerciseStates: [ExerciseState] = []
    public var programs: [ProgramDTO] = []
    public var sessions: [Session] = []
    public var records: [Record] = []
    public var goals: [GoalDTO] = []
    public var achievements: [AchievementDTO] = []
    public var nutritionLogs: [NutritionDay] = []
    public var calorieAdjustments: [Adjustment] = []

    public init(exportedAt: Date = .now, appVersion: String, includesPhotos: Bool) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.includesPhotos = includesPhotos
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, appVersion, includesPhotos, profile, settings, baselines, weights, measurements, photos
        case customExercises, exerciseStates, programs, sessions, records, goals, achievements, nutritionLogs, calorieAdjustments
    }

    /// Every section is optional on decode so older or partial files still open.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .distantPast
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? ""
        includesPhotos = try container.decodeIfPresent(Bool.self, forKey: .includesPhotos) ?? false
        profile = try container.decodeIfPresent(Profile.self, forKey: .profile)
        settings = try container.decodeIfPresent(Settings.self, forKey: .settings)
        baselines = try container.decodeIfPresent([Baseline].self, forKey: .baselines) ?? []
        weights = try container.decodeIfPresent([Weight].self, forKey: .weights) ?? []
        measurements = try container.decodeIfPresent([Measurement].self, forKey: .measurements) ?? []
        photos = try container.decodeIfPresent([Photo].self, forKey: .photos) ?? []
        customExercises = try container.decodeIfPresent([CustomExercise].self, forKey: .customExercises) ?? []
        exerciseStates = try container.decodeIfPresent([ExerciseState].self, forKey: .exerciseStates) ?? []
        programs = try container.decodeIfPresent([ProgramDTO].self, forKey: .programs) ?? []
        sessions = try container.decodeIfPresent([Session].self, forKey: .sessions) ?? []
        records = try container.decodeIfPresent([Record].self, forKey: .records) ?? []
        goals = try container.decodeIfPresent([GoalDTO].self, forKey: .goals) ?? []
        achievements = try container.decodeIfPresent([AchievementDTO].self, forKey: .achievements) ?? []
        nutritionLogs = try container.decodeIfPresent([NutritionDay].self, forKey: .nutritionLogs) ?? []
        calorieAdjustments = try container.decodeIfPresent([Adjustment].self, forKey: .calorieAdjustments) ?? []
    }

    // MARK: Nested records (mirror the SwiftData models)

    public struct Profile: Codable, Equatable, Sendable {
        public var id: UUID
        public var createdAt: Date
        public var onboardingCompleted: Bool
        public var sex: String
        public var birthDate: Date?
        public var heightCm: Double
        public var experience: String
        public var goal: String
        public var trainingWeekdays: [Int]
        public var sessionMinutes: Int
        public var activity: String
        public var equipment: [String]
        public var dumbbellMaxKg: Double
        public var hasMicroPlates: Bool
        public var limitations: [String]
        public var dietExclusions: [String]
        public var mealsPerDay: Int
        public var budget: String
        public var targetWeightKg: Double?
        public var bodyFatPercent: Double?
        public var surplusPercentOverride: Double?
        public var proteinPerKg: Double
        public var fatPerKg: Double
        public var calorieAdjustmentKcal: Int
        public var trainingDayCarbBoostKcal: Int
        public var activeProgramID: UUID?
        public var blockStartDate: Date?

        public init(id: UUID, createdAt: Date, onboardingCompleted: Bool, sex: String, birthDate: Date?, heightCm: Double, experience: String, goal: String, trainingWeekdays: [Int], sessionMinutes: Int, activity: String, equipment: [String], dumbbellMaxKg: Double, hasMicroPlates: Bool, limitations: [String], dietExclusions: [String], mealsPerDay: Int, budget: String, targetWeightKg: Double?, bodyFatPercent: Double?, surplusPercentOverride: Double?, proteinPerKg: Double, fatPerKg: Double, calorieAdjustmentKcal: Int, trainingDayCarbBoostKcal: Int, activeProgramID: UUID?, blockStartDate: Date?) {
            self.id = id
            self.createdAt = createdAt
            self.onboardingCompleted = onboardingCompleted
            self.sex = sex
            self.birthDate = birthDate
            self.heightCm = heightCm
            self.experience = experience
            self.goal = goal
            self.trainingWeekdays = trainingWeekdays
            self.sessionMinutes = sessionMinutes
            self.activity = activity
            self.equipment = equipment
            self.dumbbellMaxKg = dumbbellMaxKg
            self.hasMicroPlates = hasMicroPlates
            self.limitations = limitations
            self.dietExclusions = dietExclusions
            self.mealsPerDay = mealsPerDay
            self.budget = budget
            self.targetWeightKg = targetWeightKg
            self.bodyFatPercent = bodyFatPercent
            self.surplusPercentOverride = surplusPercentOverride
            self.proteinPerKg = proteinPerKg
            self.fatPerKg = fatPerKg
            self.calorieAdjustmentKcal = calorieAdjustmentKcal
            self.trainingDayCarbBoostKcal = trainingDayCarbBoostKcal
            self.activeProgramID = activeProgramID
            self.blockStartDate = blockStartDate
        }
    }

    public struct Settings: Codable, Equatable, Sendable {
        public var barbellStepKg: Double
        public var dumbbellStepKg: Double
        public var machineStepKg: Double
        public var barWeightKg: Double
        public var platesKg: [Double]
        public var defaultRestSeconds: Int
        public var autoStartRestTimer: Bool
        public var soundEnabled: Bool
        public var hapticsEnabled: Bool
        public var theme: String
        public var oneRMFormula: String
        public var useWellnessCheck: Bool
        public var trainingReminderEnabled: Bool
        public var trainingReminderMinutes: Int
        public var weighInReminderEnabled: Bool
        public var weighInReminderMinutes: Int
        public var waterReminderEnabled: Bool
        public var missedWorkoutReminderEnabled: Bool
        public var backupReminderEnabled: Bool
        public var lastBackupAt: Date?

        public init(barbellStepKg: Double, dumbbellStepKg: Double, machineStepKg: Double, barWeightKg: Double, platesKg: [Double], defaultRestSeconds: Int, autoStartRestTimer: Bool, soundEnabled: Bool, hapticsEnabled: Bool, theme: String, oneRMFormula: String, useWellnessCheck: Bool, trainingReminderEnabled: Bool, trainingReminderMinutes: Int, weighInReminderEnabled: Bool, weighInReminderMinutes: Int, waterReminderEnabled: Bool, missedWorkoutReminderEnabled: Bool, backupReminderEnabled: Bool, lastBackupAt: Date?) {
            self.barbellStepKg = barbellStepKg
            self.dumbbellStepKg = dumbbellStepKg
            self.machineStepKg = machineStepKg
            self.barWeightKg = barWeightKg
            self.platesKg = platesKg
            self.defaultRestSeconds = defaultRestSeconds
            self.autoStartRestTimer = autoStartRestTimer
            self.soundEnabled = soundEnabled
            self.hapticsEnabled = hapticsEnabled
            self.theme = theme
            self.oneRMFormula = oneRMFormula
            self.useWellnessCheck = useWellnessCheck
            self.trainingReminderEnabled = trainingReminderEnabled
            self.trainingReminderMinutes = trainingReminderMinutes
            self.weighInReminderEnabled = weighInReminderEnabled
            self.weighInReminderMinutes = weighInReminderMinutes
            self.waterReminderEnabled = waterReminderEnabled
            self.missedWorkoutReminderEnabled = missedWorkoutReminderEnabled
            self.backupReminderEnabled = backupReminderEnabled
            self.lastBackupAt = lastBackupAt
        }
    }

    public struct Baseline: Codable, Equatable, Sendable {
        public var id: UUID, exerciseSlug: String, weightKg: Double, reps: Int, date: Date
        public init(id: UUID, exerciseSlug: String, weightKg: Double, reps: Int, date: Date) {
            self.id = id; self.exerciseSlug = exerciseSlug; self.weightKg = weightKg; self.reps = reps; self.date = date
        }
    }

    public struct Weight: Codable, Equatable, Sendable {
        public var id: UUID, date: Date, weightKg: Double
        public init(id: UUID, date: Date, weightKg: Double) {
            self.id = id; self.date = date; self.weightKg = weightKg
        }
    }

    public struct Measurement: Codable, Equatable, Sendable {
        public var id: UUID, date: Date, kind: String, valueCm: Double
        public init(id: UUID, date: Date, kind: String, valueCm: Double) {
            self.id = id; self.date = date; self.kind = kind; self.valueCm = valueCm
        }
    }

    public struct Photo: Codable, Equatable, Sendable {
        public var id: UUID, date: Date, fileName: String, angle: String, note: String
        /// JPEG data when photos are included.
        public var imageData: Data?
        public init(id: UUID, date: Date, fileName: String, angle: String, note: String, imageData: Data?) {
            self.id = id; self.date = date; self.fileName = fileName; self.angle = angle; self.note = note; self.imageData = imageData
        }
    }

    public struct CustomExercise: Codable, Equatable, Sendable {
        public var slug: String, nameUk: String, nameEn: String, synonyms: [String]
        public var primaryMuscles: [String], secondaryMuscles: [String], equipment: [String]
        public var mechanic: String, level: String, region: String, progression: String
        public var techniqueSteps: [String], commonMistakes: [String], safetyTips: [String], breathing: String
        public var alternatives: [String], riskAreas: [String], isFavorite: Bool
        public var customImageFileName: String?
        public var imageData: Data?
        public init(slug: String, nameUk: String, nameEn: String, synonyms: [String], primaryMuscles: [String], secondaryMuscles: [String], equipment: [String], mechanic: String, level: String, region: String, progression: String, techniqueSteps: [String], commonMistakes: [String], safetyTips: [String], breathing: String, alternatives: [String], riskAreas: [String], isFavorite: Bool, customImageFileName: String?, imageData: Data?) {
            self.slug = slug; self.nameUk = nameUk; self.nameEn = nameEn; self.synonyms = synonyms
            self.primaryMuscles = primaryMuscles; self.secondaryMuscles = secondaryMuscles; self.equipment = equipment
            self.mechanic = mechanic; self.level = level; self.region = region; self.progression = progression
            self.techniqueSteps = techniqueSteps; self.commonMistakes = commonMistakes; self.safetyTips = safetyTips; self.breathing = breathing
            self.alternatives = alternatives; self.riskAreas = riskAreas; self.isFavorite = isFavorite
            self.customImageFileName = customImageFileName; self.imageData = imageData
        }
    }

    public struct ExerciseState: Codable, Equatable, Sendable {
        public var slug: String, isFavorite: Bool, customImageFileName: String?, imageData: Data?
        public init(slug: String, isFavorite: Bool, customImageFileName: String?, imageData: Data?) {
            self.slug = slug; self.isFavorite = isFavorite; self.customImageFileName = customImageFileName; self.imageData = imageData
        }
    }

    public struct ProgramDTO: Codable, Equatable, Sendable {
        public struct Day: Codable, Equatable, Sendable {
            public var id: UUID, order: Int, name: String, focus: String, exercises: [Planned]
            public init(id: UUID, order: Int, name: String, focus: String, exercises: [Planned]) {
                self.id = id; self.order = order; self.name = name; self.focus = focus; self.exercises = exercises
            }
        }

        public struct Planned: Codable, Equatable, Sendable {
            public var id: UUID, order: Int, exerciseSlug: String, sets: Int, repMin: Int, repMax: Int
            public var restSeconds: Int, targetRIR: Int, progression: String, incrementKg: Double?, note: String
            public init(id: UUID, order: Int, exerciseSlug: String, sets: Int, repMin: Int, repMax: Int, restSeconds: Int, targetRIR: Int, progression: String, incrementKg: Double?, note: String) {
                self.id = id; self.order = order; self.exerciseSlug = exerciseSlug; self.sets = sets; self.repMin = repMin; self.repMax = repMax
                self.restSeconds = restSeconds; self.targetRIR = targetRIR; self.progression = progression; self.incrementKg = incrementKg; self.note = note
            }
        }

        public var id: UUID, name: String, summary: String, audience: String, recommendedWeeks: Int
        public var progressionNotes: String, isBuiltIn: Bool, seedSlug: String?, createdAt: Date, days: [Day]
        public init(id: UUID, name: String, summary: String, audience: String, recommendedWeeks: Int, progressionNotes: String, isBuiltIn: Bool, seedSlug: String?, createdAt: Date, days: [Day]) {
            self.id = id; self.name = name; self.summary = summary; self.audience = audience; self.recommendedWeeks = recommendedWeeks
            self.progressionNotes = progressionNotes; self.isBuiltIn = isBuiltIn; self.seedSlug = seedSlug; self.createdAt = createdAt; self.days = days
        }
    }

    public struct Session: Codable, Equatable, Sendable {
        public struct Exercise: Codable, Equatable, Sendable {
            public var id: UUID, order: Int, exerciseSlug: String, exerciseName: String
            public var plannedSets: Int, repMin: Int, repMax: Int, restSeconds: Int, targetRIR: Int
            public var isSkipped: Bool, note: String, sets: [SetDTO]
            public init(id: UUID, order: Int, exerciseSlug: String, exerciseName: String, plannedSets: Int, repMin: Int, repMax: Int, restSeconds: Int, targetRIR: Int, isSkipped: Bool, note: String, sets: [SetDTO]) {
                self.id = id; self.order = order; self.exerciseSlug = exerciseSlug; self.exerciseName = exerciseName
                self.plannedSets = plannedSets; self.repMin = repMin; self.repMax = repMax; self.restSeconds = restSeconds; self.targetRIR = targetRIR
                self.isSkipped = isSkipped; self.note = note; self.sets = sets
            }
        }

        public struct SetDTO: Codable, Equatable, Sendable {
            public var id: UUID, order: Int, weightKg: Double, reps: Int, durationSeconds: Int?, rir: Int?
            public var isWarmup: Bool, isCompleted: Bool, completedAt: Date?, note: String
            public init(id: UUID, order: Int, weightKg: Double, reps: Int, durationSeconds: Int?, rir: Int?, isWarmup: Bool, isCompleted: Bool, completedAt: Date?, note: String) {
                self.id = id; self.order = order; self.weightKg = weightKg; self.reps = reps; self.durationSeconds = durationSeconds; self.rir = rir
                self.isWarmup = isWarmup; self.isCompleted = isCompleted; self.completedAt = completedAt; self.note = note
            }
        }

        public var id: UUID, startedAt: Date, endedAt: Date?, isFinished: Bool, programDayID: UUID?, title: String
        public var isDeload: Bool, wellnessSleep: Int?, wellnessFatigue: Int?, wellnessSoreness: Int?, feeling: Int?, note: String
        public var exercises: [Exercise]
        public init(id: UUID, startedAt: Date, endedAt: Date?, isFinished: Bool, programDayID: UUID?, title: String, isDeload: Bool, wellnessSleep: Int?, wellnessFatigue: Int?, wellnessSoreness: Int?, feeling: Int?, note: String, exercises: [Exercise]) {
            self.id = id; self.startedAt = startedAt; self.endedAt = endedAt; self.isFinished = isFinished; self.programDayID = programDayID; self.title = title
            self.isDeload = isDeload; self.wellnessSleep = wellnessSleep; self.wellnessFatigue = wellnessFatigue; self.wellnessSoreness = wellnessSoreness
            self.feeling = feeling; self.note = note; self.exercises = exercises
        }
    }

    public struct Record: Codable, Equatable, Sendable {
        public var id: UUID, exerciseSlug: String, kind: String, repTarget: Int, value: Double, weightKg: Double, reps: Int, date: Date, sessionID: UUID?
        public init(id: UUID, exerciseSlug: String, kind: String, repTarget: Int, value: Double, weightKg: Double, reps: Int, date: Date, sessionID: UUID?) {
            self.id = id; self.exerciseSlug = exerciseSlug; self.kind = kind; self.repTarget = repTarget; self.value = value
            self.weightKg = weightKg; self.reps = reps; self.date = date; self.sessionID = sessionID
        }
    }

    public struct GoalDTO: Codable, Equatable, Sendable {
        public var id: UUID, kind: String, title: String, startValue: Double, targetValue: Double
        public var exerciseSlug: String?, measurementKind: String?, deadline: Date?, createdAt: Date, achievedAt: Date?
        public init(id: UUID, kind: String, title: String, startValue: Double, targetValue: Double, exerciseSlug: String?, measurementKind: String?, deadline: Date?, createdAt: Date, achievedAt: Date?) {
            self.id = id; self.kind = kind; self.title = title; self.startValue = startValue; self.targetValue = targetValue
            self.exerciseSlug = exerciseSlug; self.measurementKind = measurementKind; self.deadline = deadline; self.createdAt = createdAt; self.achievedAt = achievedAt
        }
    }

    public struct AchievementDTO: Codable, Equatable, Sendable {
        public var key: String, unlockedAt: Date
        public init(key: String, unlockedAt: Date) {
            self.key = key; self.unlockedAt = unlockedAt
        }
    }

    public struct NutritionDay: Codable, Equatable, Sendable {
        public struct Entry: Codable, Equatable, Sendable {
            public var id: UUID, time: Date, name: String, grams: Double?, kcal: Double, protein: Double, fat: Double, carbs: Double
            public init(id: UUID, time: Date, name: String, grams: Double?, kcal: Double, protein: Double, fat: Double, carbs: Double) {
                self.id = id; self.time = time; self.name = name; self.grams = grams; self.kcal = kcal; self.protein = protein; self.fat = fat; self.carbs = carbs
            }
        }

        public var id: UUID, day: Date, waterMl: Int, entries: [Entry]
        public init(id: UUID, day: Date, waterMl: Int, entries: [Entry]) {
            self.id = id; self.day = day; self.waterMl = waterMl; self.entries = entries
        }
    }

    public struct Adjustment: Codable, Equatable, Sendable {
        public var id: UUID, date: Date, deltaKcal: Int, weeklyGainPercent: Double, accepted: Bool
        public init(id: UUID, date: Date, deltaKcal: Int, weeklyGainPercent: Double, accepted: Bool) {
            self.id = id; self.date = date; self.deltaKcal = deltaKcal; self.weeklyGainPercent = weeklyGainPercent; self.accepted = accepted
        }
    }
}

public enum BackupCodec {
    public enum DecodeError: Error, Equatable, Sendable {
        case notABackup
        /// File comes from a newer app version.
        case unsupportedVersion(Int)
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int?
    }

    public static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Seconds since 1970: exact round trip (ISO strings lose sub-millisecond precision).
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(file)
    }

    public static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let probe = try? decoder.decode(VersionProbe.self, from: data), let version = probe.schemaVersion else {
            throw DecodeError.notABackup
        }
        guard version <= BackupFile.currentSchemaVersion else { throw DecodeError.unsupportedVersion(version) }
        // Older versions would be migrated here before decoding the current shape.
        return try decoder.decode(BackupFile.self, from: data)
    }

    public static func fileName(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "Zalizo-backup-\(formatter.string(from: date)).json"
    }
}

/// Workout history as CSV for Excel/Numbers (semicolon-separated, decimal comma friendly).
public enum CSVExport {
    public static let header = "Дата;Тренування;Вправа;Підхід;Вага, кг;Повтори;RIR;Розминка"

    public static func workouts(_ sessions: [BackupFile.Session], calendar: Calendar = .current) -> String {
        var lines = [header]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        for session in sessions.filter(\.isFinished).sorted(by: { $0.startedAt < $1.startedAt }) {
            for exercise in session.exercises.sorted(by: { $0.order < $1.order }) {
                for (index, set) in exercise.sets.filter(\.isCompleted).sorted(by: { $0.order < $1.order }).enumerated() {
                    lines.append([
                        formatter.string(from: session.startedAt),
                        escape(session.title),
                        escape(exercise.exerciseName),
                        "\(index + 1)",
                        decimal(set.weightKg),
                        "\(set.reps)",
                        set.rir.map(String.init) ?? "",
                        set.isWarmup ? "так" : ""
                    ].joined(separator: ";"))
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ value: String) -> String {
        guard value.contains(";") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func decimal(_ value: Double) -> String {
        let text = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        return text.replacingOccurrences(of: ".", with: ",")
    }
}
