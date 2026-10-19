import Foundation
@testable import ShahCore

let kyiv = TimeZone(identifier: "Europe/Kyiv")!
let newYork = TimeZone(identifier: "America/New_York")!
let tokyo = TimeZone(identifier: "Asia/Tokyo")!
let santiago = TimeZone(identifier: "America/Santiago")!

func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey {
    DayKey(year: y, month: m, day: d)
}

/// A wall-clock moment in `zone`.
func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, in zone: TimeZone = kyiv) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

func history(_ km: [DayKey: Double], zone: TimeZone = kyiv) -> History {
    History(
        totals: Dictionary(uniqueKeysWithValues: km.map { ($0.key, DayTotal(day: $0.key, meters: $0.value * 1000, steps: Int($0.value * 1400))) }),
        timeZoneID: zone.identifier,
        updatedAt: nil
    )
}

/// History with consecutive days ending `end`, oldest first.
func history(endingOn end: DayKey, km: [Double]) -> History {
    var dict: [DayKey: Double] = [:]
    for (i, value) in km.enumerated() {
        dict[end.advanced(by: i - (km.count - 1))] = value
    }
    return history(dict)
}

/// Mutable clock for repository tests.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    private var _zone: TimeZone

    init(_ now: Date, zone: TimeZone = kyiv) {
        _now = now
        _zone = zone
    }

    var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }

    var zone: TimeZone {
        get { lock.withLock { _zone } }
        set { lock.withLock { _zone = newValue } }
    }
}
