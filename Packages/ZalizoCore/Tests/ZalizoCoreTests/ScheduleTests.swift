import Foundation
import Testing
@testable import ZalizoCore

@Suite("TrainingSchedule")
struct ScheduleTests {
    var iso: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = utc.timeZone
        return calendar
    }

    /// 2026-10-19 is a Monday.
    func date(_ day: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .now
    }

    let mwf: [Weekday] = [.monday, .wednesday, .friday]

    @Test func trainingDayTodayStartsFirstDay() throws {
        let next = try #require(TrainingSchedule.next(trainingDays: mwf, dayCount: 3, lastDayIndex: nil, trainedToday: false, today: date(19), calendar: utc))
        #expect(next.isToday)
        #expect(next.dayIndex == 0)
    }

    @Test func restDayPointsToNextTrainingDay() throws {
        // Tuesday after day A → Wednesday, day B
        let next = try #require(TrainingSchedule.next(trainingDays: mwf, dayCount: 3, lastDayIndex: 0, trainedToday: false, today: date(20), calendar: utc))
        #expect(!next.isToday)
        #expect(utc.isDate(next.date, inSameDayAs: date(21)))
        #expect(next.dayIndex == 1)
    }

    @Test func afterTrainingTodayNextIsLater() throws {
        let next = try #require(TrainingSchedule.next(trainingDays: mwf, dayCount: 3, lastDayIndex: 0, trainedToday: true, today: date(19), calendar: utc))
        #expect(utc.isDate(next.date, inSameDayAs: date(21)))
    }

    @Test func rotationWrapsAround() throws {
        let next = try #require(TrainingSchedule.next(trainingDays: mwf, dayCount: 2, lastDayIndex: 1, trainedToday: false, today: date(23), calendar: utc))
        #expect(next.dayIndex == 0) // A/B program: after B comes A
        #expect(TrainingSchedule.next(trainingDays: mwf, dayCount: 0, lastDayIndex: nil, trainedToday: false) == nil)
    }

    @Test func weekCountsAndStreak() {
        // Weeks of Oct 5, Oct 12 complete (3 each); current week (Oct 19) has 1 so far.
        let dates = [5, 7, 9, 12, 14, 16, 19].map { date($0) }
        #expect(TrainingSchedule.workoutsInWeek(of: date(21), workoutDates: dates, calendar: iso) == 1)
        #expect(TrainingSchedule.weekStreak(workoutDates: dates, target: 3, now: date(21), calendar: iso) == 2)
        // Week of Oct 12 incomplete → streak broken
        let broken = [5, 7, 9, 12, 14, 19].map { date($0) }
        #expect(TrainingSchedule.weekStreak(workoutDates: broken, target: 3, now: date(21), calendar: iso) == 0)
        // Current week complete counts too
        let full = dates + [date(21), date(23)]
        #expect(TrainingSchedule.weekStreak(workoutDates: full, target: 3, now: date(23), calendar: iso) == 3)
        #expect(TrainingSchedule.weekStreak(workoutDates: [], target: 3, now: date(23), calendar: iso) == 0)
    }

    @Test func missedYesterday() {
        // Tuesday: Monday was a training day
        #expect(TrainingSchedule.missedYesterday(trainingDays: mwf, workoutDates: [], now: date(20), calendar: utc))
        #expect(!TrainingSchedule.missedYesterday(trainingDays: mwf, workoutDates: [date(19, hour: 18)], now: date(20), calendar: utc))
        // Wednesday: Tuesday was a rest day
        #expect(!TrainingSchedule.missedYesterday(trainingDays: mwf, workoutDates: [], now: date(21), calendar: utc))
    }
}
