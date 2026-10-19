import Foundation

/// Which program day comes next and when. Program days rotate in order on the user's training weekdays
/// (Full Body A/B on Mon/Wed/Fri gives A/B/A, then B/A/B).
public enum TrainingSchedule {
    public struct Next: Equatable, Sendable {
        public let date: Date
        /// Index into the ordered program days.
        public let dayIndex: Int
        public let isToday: Bool
    }

    /// - Parameters:
    ///   - lastDayIndex: program day index of the last finished workout (nil → start from the first day).
    ///   - trainedToday: a workout has already been finished today.
    public static func next(
        trainingDays: [Weekday], dayCount: Int, lastDayIndex: Int?, trainedToday: Bool,
        today: Date = .now, calendar: Calendar = .current
    ) -> Next? {
        guard dayCount > 0 else { return nil }
        let index = lastDayIndex.map { ($0 + 1) % dayCount } ?? 0
        let days = trainingDays.isEmpty ? Defaults.trainingDays : trainingDays
        let start = calendar.startOfDay(for: today)
        for offset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if offset == 0 && trainedToday { continue }
            if days.contains(Weekday.from(date: date, calendar: calendar)) {
                return Next(date: date, dayIndex: index, isToday: offset == 0)
            }
        }
        return nil
    }

    /// Workouts finished in the ISO week containing `date`.
    public static func workoutsInWeek(of date: Date, workoutDates: [Date], calendar: Calendar = .iso) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return workoutDates.filter { week.containsHalfOpen($0) }.count
    }

    /// Consecutive weeks (ending with the current or the previous week) with at least `target` workouts.
    /// The current week counts only once the target is reached, so the streak is not broken mid-week.
    public static func weekStreak(workoutDates: [Date], target: Int, now: Date = .now, calendar: Calendar = .iso) -> Int {
        guard target > 0 else { return 0 }
        var streak = 0
        for weekOffset in 0..<520 {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else { break }
            if workoutsInWeek(of: date, workoutDates: workoutDates, calendar: calendar) >= target {
                streak += 1
            } else if weekOffset > 0 {
                break
            }
        }
        return streak
    }

    /// Was there a planned training day yesterday without a workout? (gentle reminder)
    public static func missedYesterday(trainingDays: [Weekday], workoutDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return false }
        guard trainingDays.contains(Weekday.from(date: yesterday, calendar: calendar)) else { return false }
        return !workoutDates.contains { calendar.isDate($0, inSameDayAs: yesterday) }
    }
}

public extension Calendar {
    /// Monday-first ISO-8601 calendar in the current time zone (Ukrainian week convention).
    static var iso: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }
}

public extension DateInterval {
    /// `start ≤ date < end` — `contains(_:)` also includes `end`, which double-counts midnight.
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
