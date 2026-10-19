import Foundation

// Domain vocabulary shared by the app and the pure-logic services.
// Raw values are stable identifiers: they are persisted in SwiftData and in backups,
// so NEVER rename an existing raw value - add new cases instead.
// User-facing (Ukrainian) titles live in the app target (DesignSystem/DomainTitles.swift).

public enum Sex: String, Codable, CaseIterable, Sendable {
    case male
    case female
}

public enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
    /// < 1 year of consistent training
    case beginner
    /// 1-3 years
    case intermediate
    /// 3+ years
    case advanced

    /// Beginners gain faster and tolerate a larger surplus.
    public var isNovice: Bool { self == .beginner }
}

public enum TrainingGoal: String, Codable, CaseIterable, Sendable {
    case muscleGain
    case strength
    case recomposition
    case maintenance
}

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    /// Desk job + ~3 workouts/week
    case sedentary
    /// On feet part of the day + workouts
    case moderate
    /// Physical job + workouts
    case physical
}

public enum Equipment: String, Codable, CaseIterable, Sendable {
    case barbell
    case dumbbells
    case cables
    case machines
    case pullUpBar
    case dipBars
    case adjustableBench
    case ezBar
    case bodyweight
}

public enum InjuryArea: String, Codable, CaseIterable, Sendable {
    case lowerBack
    case knees
    case shoulders
    case elbows
    case wrists
}

public enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case quads
    case hamstrings
    case glutes
    case calves
    case abs
    case traps
}

public enum ExerciseMechanic: String, Codable, CaseIterable, Sendable {
    case compound
    case isolation
}

public enum ExerciseLevel: String, Codable, CaseIterable, Sendable {
    case beginner
    case intermediate
    case expert
}

/// Used to choose the default weight increment in progression.
public enum BodyRegion: String, Codable, CaseIterable, Sendable {
    case upper
    case lower
    case core
}

public enum ProgressionType: String, Codable, CaseIterable, Sendable {
    /// Classic double progression on load (reps → then weight)
    case doubleProgression
    /// Bodyweight movement: add reps, then add external load
    case bodyweight
    /// Timed hold (plank): add seconds
    case timed
}

public enum DietExclusion: String, Codable, CaseIterable, Sendable {
    case dairy
    case gluten
    case pork
    case fish
    case eggs
    case nuts
    case lactose
}

public enum FoodBudget: String, Codable, CaseIterable, Sendable {
    case economy
    case medium
}

public enum MeasurementKind: String, Codable, CaseIterable, Sendable {
    case chest
    case waist
    case hips
    case bicepsLeft
    case bicepsRight
    case thigh
    case calf
    case neck
}

public enum PhotoAngle: String, Codable, CaseIterable, Sendable {
    case front
    case side
    case back
}

public enum OneRMFormula: String, Codable, CaseIterable, Sendable {
    case epley
    case brzycki
}

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum GoalKind: String, Codable, CaseIterable, Sendable {
    case bodyWeight
    case liftWeight
    case workoutsPerMonth
    case measurement
}

public enum RecordKind: String, Codable, CaseIterable, Sendable {
    /// Heaviest weight lifted for any reps
    case maxWeight
    /// Best estimated 1RM
    case estimatedOneRM
    /// Best single-set volume (weight × reps)
    case setVolume
    /// Best weight for an exact rep count (1, 3, 5, 8, 10)
    case repMax
}

/// ISO weekday numbering used across the app: 1 = Monday … 7 = Sunday.
public enum Weekday: Int, Codable, CaseIterable, Sendable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Converts from `Calendar.component(.weekday)` (1 = Sunday … 7 = Saturday).
    public init(gregorianWeekday: Int) {
        let iso = gregorianWeekday == 1 ? 7 : gregorianWeekday - 1
        self = Weekday(rawValue: iso) ?? .monday
    }

    public static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        Weekday(gregorianWeekday: calendar.component(.weekday, from: date))
    }
}
