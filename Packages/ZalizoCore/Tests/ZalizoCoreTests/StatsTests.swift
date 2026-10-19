import Foundation
import Testing
@testable import ZalizoCore

@Suite("Stats")
struct StatsTests {
    var iso: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = utc.timeZone
        return calendar
    }

    func bench(_ weight: Double, _ reps: [Int]) -> SessionRecord.Exercise {
        .init(slug: "bench", primary: [.chest], secondary: [.triceps], sets: reps.map { PerformedSet(weight: weight, reps: $0) })
    }

    var sessions: [SessionRecord] {
        [
            SessionRecord(date: day(-14), durationSeconds: 3600, exercises: [bench(60, [10, 10, 9])]),
            SessionRecord(date: day(-7), durationSeconds: 4200, exercises: [bench(70, [8, 8, 6]), .init(slug: "row", primary: [.back], secondary: [.biceps], sets: [PerformedSet(weight: 50, reps: 10)])]),
            SessionRecord(date: day(0), durationSeconds: 0, exercises: [bench(72.5, [5, 5, 5])])
        ]
    }

    @Test func exerciseSeries() throws {
        let series = StatsService.exerciseSeries(sessions.reversed(), slug: "bench")
        #expect(series.count == 3)
        #expect(series.first?.maxWeight == 60)
        #expect(approx(try #require(series.first).estimatedOneRM, 80))
        #expect(series[1].tonnage == 70 * 22)
        #expect(StatsService.exerciseSeries(sessions, slug: "squat").isEmpty)
    }

    @Test func repRecords() throws {
        let records = StatsService.repRecords(sessions, slug: "bench")
        let byReps = Dictionary(uniqueKeysWithValues: records.map { ($0.reps, $0) })
        #expect(byReps[1]?.weight == 72.5)
        #expect(byReps[5]?.weight == 72.5)
        #expect(byReps[8]?.weight == 70)
        #expect(byReps[10]?.weight == 60)
        #expect(try #require(byReps[10]).date == day(-14))
    }

    @Test func overview() {
        let all = StatsService.overview(sessions, period: .all, now: day(0), calendar: utc)
        #expect(all.workouts == 3)
        #expect(all.averageDurationMinutes == 65) // (60 + 70) / 2, zero duration ignored
        let expected = 1740.0 + 1540.0 + 500.0 + 1087.5 // 60×29 + 70×22 + 50×10 + 72.5×15
        #expect(all.totalTonnage == expected)
        let recent = StatsService.overview(sessions, period: .fourWeeks, now: day(0), calendar: utc)
        #expect(approx(recent.workoutsPerWeek, 0.75))
    }

    @Test func periods() {
        #expect(StatsPeriod.fourWeeks.contains(day(-20), now: day(0), calendar: utc))
        #expect(!StatsPeriod.fourWeeks.contains(day(-40), now: day(0), calendar: utc))
        #expect(StatsPeriod.all.contains(.distantPast))
        #expect(StatsPeriod.all.startDate() == nil)
    }

    @Test func workoutsPerWeek() {
        let weeks = StatsService.workoutsPerWeek(sessions.map(\.date), weeks: 4, now: day(0), calendar: iso)
        #expect(weeks.count == 4)
        #expect(weeks.map(\.count).reduce(0, +) == 3)
        #expect(weeks.last?.count == 1)
        #expect(weeks.map(\.weekStart) == weeks.map(\.weekStart).sorted())
    }

    @Test func dailyCountsAndWeeklyMuscles() {
        let counts = StatsService.dailyCounts(sessions.map(\.date) + [day(0).addingTimeInterval(3600)], calendar: utc)
        #expect(counts[utc.startOfDay(for: day(0))] == 2)
        let muscles = StatsService.weeklyMuscleSets(sessions, weekOf: day(-7), calendar: iso)
        #expect(muscles[.chest] == 3)
        #expect(muscles[.triceps] == 1.5)
        #expect(muscles[.back] == 1)
    }

    @Test func measurementChange() {
        let points = [StatsService.MeasurementPoint(date: day(10), value: 38), .init(date: day(0), value: 36.5)]
        #expect(StatsService.change(points) == 1.5)
        #expect(StatsService.change([points[0]]) == nil)
    }
}
