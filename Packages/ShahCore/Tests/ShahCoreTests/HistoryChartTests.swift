import Foundation
import Testing
@testable import ShahCore

@Suite("Periods and charts")
struct HistoryChartTests {
    let today = day(2026, 10, 18) // Sunday

    @Test func weekStartsOnLocaleFirstWeekday() {
        let monday = PeriodWindow.containing(today, period: .week, firstWeekday: 2) // uk_UA
        #expect(monday.start == day(2026, 10, 12))
        #expect(monday.end == day(2026, 10, 18))
        let sunday = PeriodWindow.containing(today, period: .week, firstWeekday: 1) // en_US
        #expect(sunday.start == day(2026, 10, 18))
        #expect(sunday.end == day(2026, 10, 24))
    }

    @Test func monthAndYearWindows() {
        let feb = PeriodWindow.containing(day(2028, 2, 10), period: .month, firstWeekday: 2)
        #expect(feb.start == day(2028, 2, 1) && feb.end == day(2028, 2, 29))
        let year = PeriodWindow.containing(today, period: .year, firstWeekday: 2)
        #expect(year.start == day(2026, 1, 1) && year.end == day(2026, 12, 31))
        #expect(year.days.count == 365)
    }

    @Test func shiftingWindows() {
        let week = PeriodWindow.containing(today, period: .week, firstWeekday: 2)
        #expect(week.shifted(by: -1, firstWeekday: 2).start == day(2026, 10, 5))
        let jan = PeriodWindow.containing(day(2026, 1, 15), period: .month, firstWeekday: 2)
        #expect(jan.shifted(by: -1, firstWeekday: 2).start == day(2025, 12, 1))
        #expect(jan.shifted(by: -13, firstWeekday: 2).start == day(2024, 12, 1))
        #expect(jan.shifted(by: 11, firstWeekday: 2).end == day(2026, 12, 31))
        let year = PeriodWindow.containing(today, period: .year, firstWeekday: 2)
        #expect(year.shifted(by: -2, firstWeekday: 2).start == day(2024, 1, 1))
    }

    @Test func weekBarsMarkFutureAndGoal() {
        let h = history(endingOn: today, km: [6.1, 8.3, 4.2, 10.4, 7.9, 12.6, 7.4])
        let window = PeriodWindow.containing(day(2026, 10, 16), period: .week, firstWeekday: 2)
        let bars = HistoryChart.bars(for: window, history: h, today: day(2026, 10, 16), goalMeters: 10_000)
        #expect(bars.count == 7)
        #expect(bars.map(\.goalMet) == [false, false, false, true, false, false, false])
        #expect(bars.map(\.isFuture) == [false, false, false, false, false, true, true])
        #expect(bars[5].meters == 0) // future days show nothing even if data exists
    }

    @Test func periodSummary() {
        let h = history(endingOn: today, km: [6.1, 8.3, 4.2, 10.4, 7.9, 12.6, 7.4])
        let window = PeriodWindow.containing(today, period: .week, firstWeekday: 2)
        let s = HistoryChart.summary(for: window, history: h, today: today)
        #expect(abs(s.totalMeters - 56_900) < 0.001)
        #expect(abs(s.averageMeters! - 56_900 / 7) < 0.001)
        #expect(s.bestDay?.day == day(2026, 10, 17))
        #expect(s.countedDays == 7)
    }

    @Test func summaryIgnoresFutureAndDaysBeforeFirstData() {
        let h = history([day(2026, 10, 14): 4, day(2026, 10, 15): 6])
        let window = PeriodWindow.containing(day(2026, 10, 15), period: .week, firstWeekday: 2)
        let s = HistoryChart.summary(for: window, history: h, today: day(2026, 10, 15))
        #expect(s.countedDays == 2) // 14th and 15th, not Mon–Wed before the first data, not the future
        #expect(s.averageMeters == 5_000)
    }

    @Test func emptyHistorySummary() {
        let window = PeriodWindow.containing(today, period: .month, firstWeekday: 2)
        let s = HistoryChart.summary(for: window, history: .empty(), today: today)
        #expect(s.totalMeters == 0)
        #expect(s.averageMeters == nil)
        #expect(s.bestDay == nil)
    }

    @Test func yearBarsAreMonthlyDailyAverages() {
        var km: [DayKey: Double] = [:]
        for d in DayKey.range(day(2026, 9, 1), through: day(2026, 9, 30)) { km[d] = 6 }
        for d in DayKey.range(day(2026, 10, 1), through: day(2026, 10, 18)) { km[d] = 12 }
        let window = PeriodWindow.containing(today, period: .year, firstWeekday: 2)
        let bars = HistoryChart.bars(for: window, history: history(km), today: today, goalMeters: 10_000)
        #expect(bars.count == 12)
        #expect(bars[0].meters == 0)                 // before first data
        #expect(bars[8].meters == 6_000 && !bars[8].goalMet)
        #expect(bars[9].meters == 12_000 && bars[9].goalMet) // October counts only days up to today
        #expect(bars[10].isFuture && bars[11].isFuture)
    }
}
