import Foundation
import Testing
@testable import ShahCore

@Suite("Today: yesterday, usual, goal")
struct InsightsTests {
    let today = day(2026, 10, 18)

    @Test func comparesWithYesterdayAndWeekAverage() {
        // 7 previous days average 8.2 km, yesterday 6.2 km, today 7.4 km.
        let h = history(endingOn: today, km: [6.1, 8.3, 4.2, 10.4, 7.9, 12.3, 6.2, 7.4])
        let s = Insights.today(today, history: h, goalMeters: 10_000)
        #expect(s.meters == 7_400)
        #expect(s.yesterdayMeters == 6_200)
        #expect(abs(s.weekAverageMeters! - 7_914.2857) < 0.01)
        guard case .more(let delta) = Comparison(s.meters, versus: s.yesterdayMeters!, unit: .kilometers) else {
            Issue.record("expected more than yesterday")
            return
        }
        #expect(abs(delta - 1_200) < 1e-6)
        #expect(abs(s.progress - 0.74) < 1e-9)
        #expect(!s.isGoalMet)
        #expect(abs(s.remainingMeters - 2_600) < 1e-9)
    }

    @Test func todayIsExcludedFromTheUsualAverage() {
        let h = history(endingOn: today, km: [5, 5, 5, 5, 5, 5, 5, 50])
        #expect(Insights.today(today, history: h, goalMeters: 5_000).weekAverageMeters == 5_000)
    }

    @Test func daysWithoutWalkingCountAsZero() {
        // Data 10 days ago, then nothing: the usual is 0, not undefined.
        let h = history([today.advanced(by: -10): 8])
        let s = Insights.today(today, history: h, goalMeters: 5_000)
        #expect(s.yesterdayMeters == 0)
        #expect(s.weekAverageMeters == 0)
    }

    @Test func averageOnlyCoversDaysSinceFirstData() {
        // New iPhone two days ago: average over 2 days, not 7.
        let h = history([today.advanced(by: -2): 4, today.advanced(by: -1): 6])
        #expect(Insights.today(today, history: h, goalMeters: 5_000).weekAverageMeters == 5_000)
    }

    @Test func firstLaunchWithoutHistory() {
        let s = Insights.today(today, history: .empty(), goalMeters: 5_000)
        #expect(s.meters == 0)
        #expect(s.steps == 0)
        #expect(s.yesterdayMeters == nil)
        #expect(s.weekAverageMeters == nil)
        #expect(s.progress == 0)
    }

    @Test func onlyTodayHasData() {
        let s = Insights.today(today, history: history([today: 3]), goalMeters: 5_000)
        #expect(s.meters == 3_000)
        #expect(s.yesterdayMeters == nil)
        #expect(s.weekAverageMeters == nil)
    }

    @Test func goalMetAtExactlyTheGoal() {
        let s = Insights.today(today, history: history([today: 5]), goalMeters: 5_000)
        #expect(s.isGoalMet)
        #expect(s.remainingMeters == 0)
    }

    @Test func comparisonUsesDisplayedPrecision() {
        #expect(Comparison(7_420, versus: 7_400, unit: .kilometers) == .same)       // 0.02 → "0,0"
        #expect(Comparison(7_460, versus: 7_400, unit: .kilometers) == .more(meters: 60)) // 0.06 → "0,1"
        #expect(Comparison(6_600, versus: 7_400, unit: .kilometers) == .less(meters: 800))
        #expect(Comparison(7_450, versus: 7_400, unit: .miles) == .same)            // 0.03 mi
    }
}

@Suite("Streaks")
struct StreakTests {
    let today = day(2026, 10, 18)

    @Test func currentStreakIncludesTodayWhenMet() {
        let h = history(endingOn: today, km: [2, 6, 7, 5.5])
        #expect(Insights.streak(through: today, history: h, goalMeters: 5_000) == Streak(current: 3, best: 3, includesToday: true))
    }

    @Test func streakStaysAliveUntilTodayEnds() {
        // Today 1 km so far: yesterday's run still counts.
        let h = history(endingOn: today, km: [6, 7, 8, 1])
        #expect(Insights.streak(through: today, history: h, goalMeters: 5_000) == Streak(current: 3, best: 3, includesToday: false))
    }

    @Test func brokenStreakAndRecord() {
        let h = history(endingOn: today, km: [6, 6, 6, 6, 6, 1, 6, 6, 1, 7])
        let s = Insights.streak(through: today, history: h, goalMeters: 5_000)
        #expect(s.current == 1)
        #expect(s.best == 5)
    }

    @Test func missingDayBreaksStreak() {
        let h = history([today: 6, today.advanced(by: -2): 6, today.advanced(by: -3): 6])
        #expect(Insights.streak(through: today, history: h, goalMeters: 5_000).current == 1)
    }

    @Test func emptyHistory() {
        #expect(Insights.streak(through: today, history: .empty(), goalMeters: 5_000) == .none)
    }

    @Test func noDayMet() {
        let h = history(endingOn: today, km: [1, 2, 3])
        #expect(Insights.streak(through: today, history: h, goalMeters: 5_000) == Streak(current: 0, best: 0, includesToday: false))
    }

    @Test func goalChangeAppliesToHistory() {
        let h = history(endingOn: today, km: [6, 6, 6])
        #expect(Insights.streak(through: today, history: h, goalMeters: 5_000).current == 3)
        #expect(Insights.streak(through: today, history: h, goalMeters: 8_000).current == 0)
    }
}
