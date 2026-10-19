import Foundation

/// A civil calendar date (year-month-day) with no time and no time zone.
///
/// Days are always derived from an instant *in a given time zone*, so the same
/// walk can belong to different days after travelling. Arithmetic on `DayKey`
/// is done in UTC Gregorian, where every day is exactly one day, which makes it
/// immune to DST and to the user's calendar system.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day that contains `date` in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        let c = Calendar.gregorian(timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// The first instant of this day in `timeZone`.
    ///
    /// Usually local midnight; on days where midnight is skipped by a DST jump
    /// (e.g. America/Santiago) it is the first existing instant, matching
    /// `Calendar.startOfDay(for:)` and therefore HealthKit's daily buckets.
    public func startDate(in timeZone: TimeZone) -> Date {
        let calendar = Calendar.gregorian(timeZone)
        // Noon always exists, so build it first and let the calendar find the day start.
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return calendar.startOfDay(for: noon)
    }

    /// The half-open interval [start of this day, start of next day) in `timeZone`.
    /// Its length is 23 or 25 hours on DST transition days.
    public func interval(in timeZone: TimeZone) -> DateInterval {
        DateInterval(start: startDate(in: timeZone), end: advanced(by: 1).startDate(in: timeZone))
    }

    public func advanced(by days: Int) -> DayKey {
        let utc = Calendar.gregorian(.utc)
        let date = utc.date(byAdding: .day, value: days, to: utcNoon)!
        return DayKey(date, in: .utc)
    }

    /// Number of days from `self` to `other` (positive when `other` is later).
    public func days(to other: DayKey) -> Int {
        Calendar.gregorian(.utc).dateComponents([.day], from: utcNoon, to: other.utcNoon).day!
    }

    /// 1 = Sunday … 7 = Saturday, as in `Calendar.component(.weekday, from:)`.
    public var weekday: Int {
        Calendar.gregorian(.utc).component(.weekday, from: utcNoon)
    }

    public var daysInMonth: Int {
        Calendar.gregorian(.utc).range(of: .day, in: .month, for: utcNoon)!.count
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        let m = month < 10 ? "0\(month)" : "\(month)"
        let d = day < 10 ? "0\(day)" : "\(day)"
        return "\(year)-\(m)-\(d)"
    }

    private var utcNoon: Date {
        Calendar.gregorian(.utc).date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}

extension DayKey {
    /// All days from `start` through `end`, inclusive. Empty when `end < start`.
    public static func range(_ start: DayKey, through end: DayKey) -> [DayKey] {
        let count = start.days(to: end)
        guard count >= 0 else { return [] }
        return (0...count).map { start.advanced(by: $0) }
    }
}

extension Calendar {
    static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

extension TimeZone {
    static let utc = TimeZone(identifier: "UTC")!
}
