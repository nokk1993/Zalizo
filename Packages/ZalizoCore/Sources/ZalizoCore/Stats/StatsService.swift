import Foundation

/// Value-type copy of a finished workout for statistics.
public struct SessionRecord: Equatable, Sendable {
    public struct Exercise: Equatable, Sendable {
        public var slug: String
        public var primary: [MuscleGroup]
        public var secondary: [MuscleGroup]
        /// Working sets only.
        public var sets: [PerformedSet]

        public init(slug: String, primary: [MuscleGroup], secondary: [MuscleGroup], sets: [PerformedSet]) {
            self.slug = slug
            self.primary = primary
            self.secondary = secondary
            self.sets = sets
        }
    }

    public var date: Date
    public var durationSeconds: Int
    public var exercises: [Exercise]

    public init(date: Date, durationSeconds: Int, exercises: [Exercise]) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.exercises = exercises
    }

    public var tonnage: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
        }
    }
}

public enum StatsPeriod: String, CaseIterable, Sendable {
    case fourWeeks, threeMonths, sixMonths, year, all

    public func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .fourWeeks: calendar.date(byAdding: .weekOfYear, value: -4, to: now)
        case .threeMonths: calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths: calendar.date(byAdding: .month, value: -6, to: now)
        case .year: calendar.date(byAdding: .year, value: -1, to: now)
        case .all: nil
        }
    }

    public func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let start = startDate(now: now, calendar: calendar) else { return true }
        return date >= start
    }
}

public enum StatsService {
    // MARK: Per exercise

    public struct ExercisePoint: Equatable, Sendable {
        public let date: Date
        public let estimatedOneRM: Double
        public let maxWeight: Double
        public let tonnage: Double
    }

    /// One point per workout in which the exercise was performed, oldest first.
    public static func exerciseSeries(_ sessions: [SessionRecord], slug: String, formula: OneRMFormula = .epley) -> [ExercisePoint] {
        sessions
            .sorted { $0.date < $1.date }
            .compactMap { session in
                let sets = session.exercises.filter { $0.slug == slug }.flatMap(\.sets)
                guard !sets.isEmpty else { return nil }
                return ExercisePoint(
                    date: session.date,
                    estimatedOneRM: sets.map { OneRM.estimate(weight: $0.weight, reps: $0.reps, formula: formula).value }.max() ?? 0,
                    maxWeight: sets.map(\.weight).max() ?? 0,
                    tonnage: sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
                )
            }
    }

    /// Heaviest weight for at least N reps (1, 3, 5, 8, 10) with the date it was set.
    public struct RepRecord: Equatable, Sendable {
        public let reps: Int
        public let weight: Double
        public let date: Date
    }

    public static func repRecords(_ sessions: [SessionRecord], slug: String) -> [RepRecord] {
        ExerciseBests.repTargets.compactMap { target in
            var best: RepRecord?
            for session in sessions.sorted(by: { $0.date < $1.date }) {
                for set in session.exercises.filter({ $0.slug == slug }).flatMap(\.sets) where set.reps >= target && set.weight > 0 {
                    if set.weight > (best?.weight ?? 0) {
                        best = RepRecord(reps: target, weight: set.weight, date: session.date)
                    }
                }
            }
            return best
        }
    }

    // MARK: Overall

    public struct Overview: Equatable, Sendable {
        public let workouts: Int
        public let totalTonnage: Double
        public let averageDurationMinutes: Int
        public let workoutsPerWeek: Double
    }

    public static func overview(_ sessions: [SessionRecord], period: StatsPeriod, now: Date = .now, calendar: Calendar = .current) -> Overview {
        let inPeriod = sessions.filter { period.contains($0.date, now: now, calendar: calendar) }
        let durations = inPeriod.map(\.durationSeconds).filter { $0 > 0 }
        let average = durations.isEmpty ? 0 : durations.reduce(0, +) / durations.count / 60
        let spanStart = period.startDate(now: now, calendar: calendar) ?? inPeriod.map(\.date).min() ?? now
        let weeks = max(1, now.timeIntervalSince(spanStart) / (7 * 86_400))
        return Overview(
            workouts: inPeriod.count,
            totalTonnage: inPeriod.reduce(0) { $0 + $1.tonnage },
            averageDurationMinutes: average,
            workoutsPerWeek: Double(inPeriod.count) / weeks
        )
    }

    public struct WeekCount: Equatable, Sendable {
        public let weekStart: Date
        public let count: Int
    }

    /// Workouts per ISO week for the last `weeks` weeks (oldest first, empty weeks included).
    public static func workoutsPerWeek(_ dates: [Date], weeks: Int, now: Date = .now, calendar: Calendar = .iso) -> [WeekCount] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<max(0, weeks)).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            return WeekCount(weekStart: start, count: dates.filter { $0 >= start && $0 < end }.count)
        }
    }

    /// Heat map: workouts per calendar day.
    public static func dailyCounts(_ dates: [Date], calendar: Calendar = .current) -> [Date: Int] {
        Dictionary(grouping: dates) { calendar.startOfDay(for: $0) }.mapValues(\.count)
    }

    /// Hard sets per muscle group in the ISO week containing `date` (primary 1, secondary ½).
    public static func weeklyMuscleSets(_ sessions: [SessionRecord], weekOf date: Date = .now, calendar: Calendar = .iso) -> [MuscleGroup: Double] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [:] }
        let items = sessions.filter { week.containsHalfOpen($0.date) }.flatMap { session in
            session.exercises.map { Volume.ExerciseSets(primary: $0.primary, secondary: $0.secondary, workingSets: $0.sets.count) }
        }
        return Volume.setsPerMuscle(items)
    }

    // MARK: Measurements

    public struct MeasurementPoint: Equatable, Sendable {
        public let date: Date
        public let value: Double

        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    /// Change between the first and last value (nil if fewer than two points).
    public static func change(_ points: [MeasurementPoint]) -> Double? {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else { return nil }
        return last.value - first.value
    }
}
