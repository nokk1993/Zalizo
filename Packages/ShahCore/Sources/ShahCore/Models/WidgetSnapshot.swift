import Foundation

/// Everything a widget needs, written by the app into the App Group so the
/// widget can render even while Health data is locked.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var day: DayKey
    public var meters: Double
    public var steps: Int
    public var goalMeters: Double
    public var unit: DistanceUnit
    /// Distance in metres for the 7 days ending on `day`, oldest first.
    public var week: [Double]
    public var updatedAt: Date

    public init(day: DayKey, meters: Double, steps: Int, goalMeters: Double, unit: DistanceUnit, week: [Double], updatedAt: Date) {
        self.day = day
        self.meters = meters
        self.steps = steps
        self.goalMeters = goalMeters
        self.unit = unit
        self.week = week
        self.updatedAt = updatedAt
    }

    public static func make(history: History, today: DayKey, settings: AppSettings, unit: DistanceUnit, now: Date) -> WidgetSnapshot {
        let total = history[today]
        let week = history.days(from: today.advanced(by: -6), through: today).map(\.meters)
        return WidgetSnapshot(
            day: today, meters: total.meters, steps: total.steps,
            goalMeters: settings.goalMeters, unit: unit, week: week, updatedAt: now
        )
    }

    public var progress: Double {
        goalMeters > 0 ? meters / goalMeters : 0
    }

    /// What to show at `date`. After midnight a snapshot from yesterday must not
    /// keep showing yesterday's distance as "today", so today resets to zero and
    /// the week slides forward.
    public func asOf(_ date: Date, in timeZone: TimeZone) -> WidgetSnapshot {
        let target = DayKey(date, in: timeZone)
        let gap = day.days(to: target)
        guard gap > 0 else { return self }
        var copy = self
        copy.day = target
        copy.meters = 0
        copy.steps = 0
        copy.week = gap >= week.count ? Array(repeating: 0, count: week.count)
                                       : Array(week.dropFirst(gap)) + Array(repeating: 0, count: gap)
        return copy
    }

    public static func placeholder(day: DayKey, unit: DistanceUnit) -> WidgetSnapshot {
        WidgetSnapshot(
            day: day, meters: 7_400, steps: 10_482, goalMeters: 10_000, unit: unit,
            week: [6_100, 8_300, 4_200, 10_400, 7_900, 12_600, 7_400], updatedAt: .now
        )
    }
}
