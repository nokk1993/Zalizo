import Foundation

/// Distance and steps for one day, already de-duplicated by HealthKit.
public struct DayTotal: Hashable, Codable, Sendable {
    public let day: DayKey
    public var meters: Double
    public var steps: Int

    public init(day: DayKey, meters: Double, steps: Int) {
        self.day = day
        self.meters = meters
        self.steps = steps
    }

    public static func zero(_ day: DayKey) -> DayTotal {
        DayTotal(day: day, meters: 0, steps: 0)
    }

    public var hasData: Bool { meters > 0 || steps > 0 }
}

/// Daily totals bucketed in one time zone.
public struct History: Equatable, Sendable {
    public private(set) var totals: [DayKey: DayTotal]
    public let timeZoneID: String
    public let updatedAt: Date?
    /// The earliest day that has any distance or steps. Averages ignore days
    /// before it, so a new iPhone does not drag them down with empty weeks.
    public let firstDataDay: DayKey?

    public init(totals: [DayKey: DayTotal], timeZoneID: String, updatedAt: Date?) {
        self.totals = totals
        self.timeZoneID = timeZoneID
        self.updatedAt = updatedAt
        self.firstDataDay = totals.values.lazy.filter(\.hasData).map(\.day).min()
    }

    public static func empty(timeZoneID: String = TimeZone.current.identifier) -> History {
        History(totals: [:], timeZoneID: timeZoneID, updatedAt: nil)
    }

    public var isEmpty: Bool { firstDataDay == nil }

    public subscript(day: DayKey) -> DayTotal {
        totals[day] ?? .zero(day)
    }

    /// Zero-filled, contiguous days from `start` through `end`.
    public func days(from start: DayKey, through end: DayKey) -> [DayTotal] {
        DayKey.range(start, through: end).map { self[$0] }
    }
}
