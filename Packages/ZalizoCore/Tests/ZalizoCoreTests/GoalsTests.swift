import Foundation
import Testing
@testable import ZalizoCore

@Suite("Goals & achievements")
struct GoalsTests {
    @Test func weightGoalForecast() throws {
        // 70 → 78 kg, gaining 0.05 kg/day (0.35 kg/week)
        let history = (0..<28).map { GoalProgress.Point(date: day($0), value: 70 + 0.05 * Double($0)) }
        let status = GoalProgress.status(start: 70, target: 78, history: history, deadline: day(200), now: day(27))
        #expect(approx(status.current, 71.35))
        #expect(approx(status.fraction, 1.35 / 8))
        #expect(!status.isAchieved)
        let forecast = try #require(status.forecastDate)
        // remaining 6.65 kg / 0.05 per day = 133 days after day 27
        #expect(abs(forecast.timeIntervalSince(day(160))) < 86_400 * 1.5)
        #expect(status.onTrack == true)
        #expect(GoalProgress.status(start: 70, target: 78, history: history, deadline: day(100), now: day(27)).onTrack == false)
    }

    @Test func achievedAndWrongDirection() {
        let up = [GoalProgress.Point(date: day(0), value: 100), .init(date: day(14), value: 98)]
        let status = GoalProgress.status(start: 100, target: 110, history: up, deadline: nil)
        #expect(status.forecastDate == nil)
        #expect(status.fraction == 0)
        #expect(status.onTrack == nil)
        let reached = GoalProgress.status(start: 100, target: 110, history: [.init(date: day(0), value: 111)], deadline: nil, now: day(0))
        #expect(reached.isAchieved)
        #expect(reached.fraction == 1)
        // Decreasing goal (waist)
        let waist = GoalProgress.status(start: 90, target: 85, history: [.init(date: day(0), value: 87)], deadline: nil)
        #expect(approx(waist.fraction, 0.6))
    }

    @Test func tooLittleDataHasNoForecast() {
        let short = [GoalProgress.Point(date: day(0), value: 70), .init(date: day(3), value: 70.3)]
        #expect(GoalProgress.status(start: 70, target: 75, history: short, deadline: nil).forecastDate == nil)
    }

    @Test func workoutsThisMonth() {
        let now = day(0)
        let dates = [day(0), day(-1), day(-40)]
        #expect(GoalProgress.workoutsThisMonth(dates, now: now, calendar: utc) >= 1)
        #expect(GoalProgress.workoutsThisMonth(dates, now: now, calendar: utc) <= 2)
    }

    @Test func achievementRules() {
        let none = Achievements.unlocked(.init())
        #expect(none.isEmpty)
        let some = Achievements.unlocked(.init(workouts: 12, bestWeekStreak: 4, records: 3, bodyWeightKg: 80, bestBenchKg: 80, bestSquatKg: 110, totalTonnage: 120_000))
        #expect(some == [.firstWorkout, .workouts10, .streak4Weeks, .firstRecord, .benchBodyweight, .tonnage100k])
        #expect(Achievements.unlocked(.init(bodyWeightKg: 80, bestSquatKg: 120)).contains(.squatOneAndHalf))
    }

    @Test func bestStreak() {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = utc.timeZone
        // Weeks 0,1,2 complete (2/week), week 3 empty, week 4 complete
        let dates = [0, 2, 7, 9, 14, 16, 28, 30].map { day($0) }
        #expect(Achievements.bestWeekStreak(dates, target: 2, calendar: iso) == 3)
        #expect(Achievements.bestWeekStreak([], target: 2, calendar: iso) == 0)
    }
}
