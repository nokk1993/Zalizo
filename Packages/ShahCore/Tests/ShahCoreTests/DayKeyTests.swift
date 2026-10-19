import Foundation
import Testing
@testable import ShahCore

@Suite("Days, midnight, DST and time zones")
struct DayKeyTests {
    @Test func dayOfInstantDependsOnTimeZone() {
        // 01:30 in Kyiv is still the previous evening in New York.
        let instant = date(2026, 10, 18, 1, 30, in: kyiv)
        #expect(DayKey(instant, in: kyiv) == day(2026, 10, 18))
        #expect(DayKey(instant, in: newYork) == day(2026, 10, 17))
        #expect(DayKey(instant, in: tokyo) == day(2026, 10, 18))
    }

    @Test func midnightRollover() {
        // App open at 23:59, then 00:01: the day changes and so does "today".
        let before = date(2026, 10, 18, 23, 59)
        let after = date(2026, 10, 19, 0, 1)
        #expect(DayKey(before, in: kyiv) == day(2026, 10, 18))
        #expect(DayKey(after, in: kyiv) == day(2026, 10, 19))
        #expect(DayClock.nextDayStart(after: before, in: kyiv) == date(2026, 10, 19, 0, 0))
        #expect(DayClock.nextDayStart(after: after, in: kyiv) == date(2026, 10, 20, 0, 0))
    }

    @Test func midnightRolloverAcrossYear() {
        #expect(day(2026, 12, 31).advanced(by: 1) == day(2027, 1, 1))
        #expect(day(2028, 2, 28).advanced(by: 1) == day(2028, 2, 29))
        #expect(day(2028, 3, 1).advanced(by: -1) == day(2028, 2, 29))
    }

    @Test("Spring forward: the day has 23 hours", arguments: [
        (kyiv, day(2026, 3, 29)),
        (newYork, day(2026, 3, 8)),
    ])
    func springForward(zone: TimeZone, transition: DayKey) {
        #expect(transition.interval(in: zone).duration == 23 * 3600)
        #expect(transition.advanced(by: 1).interval(in: zone).duration == 24 * 3600)
    }

    @Test("Fall back: the day has 25 hours", arguments: [
        (kyiv, day(2026, 10, 25)),
        (newYork, day(2026, 11, 1)),
    ])
    func fallBack(zone: TimeZone, transition: DayKey) {
        #expect(transition.interval(in: zone).duration == 25 * 3600)
        // 23:30 on the long day is still that day.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let lateEvening = transition.startDate(in: zone).addingTimeInterval(24.5 * 3600)
        #expect(DayKey(lateEvening, in: zone) == transition)
    }

    @Test("Every day of the year maps back to itself and days tile without gaps",
          arguments: [kyiv, newYork, tokyo, santiago, TimeZone(identifier: "Australia/Lord_Howe")!])
    func daysTileTheTimeline(zone: TimeZone) {
        var previousEnd: Date?
        for key in DayKey.range(day(2026, 1, 1), through: day(2026, 12, 31)) {
            let interval = key.interval(in: zone)
            #expect(DayKey(interval.start, in: zone) == key)
            #expect(DayKey(interval.end.addingTimeInterval(-1), in: zone) == key)
            #expect(interval.duration >= 23 * 3600 && interval.duration <= 25 * 3600)
            if let previousEnd { #expect(previousEnd == interval.start) }
            previousEnd = interval.end
        }
    }

    @Test func skippedMidnightUsesFirstExistingInstant() {
        // Chile springs forward at 24:00 on the first Saturday of September:
        // 2026-09-06 starts at 01:00 local time.
        let start = day(2026, 9, 6).startDate(in: santiago)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = santiago
        #expect(calendar.component(.hour, from: start) == 1)
        #expect(start == calendar.startOfDay(for: date(2026, 9, 6, 12, in: santiago)))
    }

    @Test func arithmeticAndOrdering() {
        #expect(day(2026, 10, 1).days(to: day(2026, 10, 18)) == 17)
        #expect(day(2026, 10, 18).days(to: day(2026, 10, 1)) == -17)
        #expect(day(2026, 10, 17) < day(2026, 10, 18))
        #expect(day(2025, 12, 31) < day(2026, 1, 1))
        #expect(DayKey.range(day(2026, 10, 30), through: day(2026, 11, 2)).count == 4)
        #expect(DayKey.range(day(2026, 11, 2), through: day(2026, 10, 30)).isEmpty)
        #expect(day(2026, 10, 18).weekday == 1) // Sunday
        #expect(day(2026, 2, 1).daysInMonth == 28)
        #expect(day(2028, 2, 1).daysInMonth == 29)
        #expect(day(2026, 3, 5).description == "2026-03-05")
    }

    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(day(2026, 10, 18))
        #expect(try JSONDecoder().decode(DayKey.self, from: data) == day(2026, 10, 18))
    }
}
