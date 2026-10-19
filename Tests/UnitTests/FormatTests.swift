import Foundation
import ShahCore
import Testing
@testable import Shah

/// Display strings. Values depend on the test device's language, so these
/// check structure (signs, units, fallbacks), not exact Ukrainian wording.
@MainActor
struct FormatTests {
    let today = DayKey(year: 2026, month: 10, day: 18)

    func summary(meters: Double, yesterday: Double?, average: Double?) -> TodaySummary {
        TodaySummary(day: today, meters: meters, steps: 10_482, goalMeters: 10_000,
                     yesterdayMeters: yesterday, weekAverageMeters: average)
    }

    @Test func signedDeltaUsesRealMinus() {
        let more = Format.signed(Comparison(7_400, versus: 6_200, unit: .kilometers), .kilometers)
        let less = Format.signed(Comparison(7_400, versus: 8_200, unit: .kilometers), .kilometers)
        #expect(more?.hasPrefix("+") == true)
        #expect(less?.hasPrefix("\u{2212}") == true)
        #expect(Format.signed(.same, .kilometers) == nil)
    }

    @Test func comparisonCards() {
        let s = summary(meters: 7_400, yesterday: 6_200, average: 8_200)
        #expect(Format.yesterday(s, .kilometers).isMore)
        #expect(!Format.usual(s, .kilometers).isMore)
        #expect(Format.usual(s, .kilometers).value.hasPrefix("\u{2212}"))
    }

    @Test func cardsWithoutHistoryShowDash() {
        let s = summary(meters: 0, yesterday: nil, average: nil)
        #expect(Format.yesterday(s, .kilometers).value == "—")
        #expect(Format.usual(s, .kilometers).value == "—")
    }

    @Test func goalUsesOnlyNeededDecimals() {
        let five = Format.goalNumber(5_000, .kilometers)
        let fiveAndHalf = Format.goalNumber(5_500, .kilometers)
        #expect(five == "5")
        #expect(fiveAndHalf.count == 3 && fiveAndHalf.hasPrefix("5") && fiveAndHalf.hasSuffix("5"))
    }

    @Test func accessibilityLabelMentionsDistanceAndPercent() {
        let label = Format.todayAccessibility(summary(meters: 7_400, yesterday: nil, average: nil), .kilometers)
        #expect(label.contains("74"))
        #expect(label.contains("7"))
    }
}
