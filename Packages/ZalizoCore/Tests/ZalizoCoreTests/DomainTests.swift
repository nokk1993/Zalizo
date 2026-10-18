import Foundation
import Testing
@testable import ZalizoCore

@Suite("Domain")
struct DomainTests {
    @Test("Gregorian weekday maps to ISO weekday", arguments: [
        (1, Weekday.sunday), (2, .monday), (4, .wednesday), (7, .saturday)
    ])
    func weekdayMapping(gregorian: Int, expected: Weekday) {
        #expect(Weekday(gregorianWeekday: gregorian) == expected)
    }

    @Test func weekdayFromDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Kyiv"))
        // 2026-10-19 is a Monday
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 12)))
        #expect(Weekday.from(date: date, calendar: calendar) == .monday)
    }

    @Test func rawValuesAreStable() {
        // Persisted identifiers — changing them would break stored data and backups.
        #expect(MuscleGroup.chest.rawValue == "chest")
        #expect(TrainingGoal.muscleGain.rawValue == "muscleGain")
        #expect(InjuryArea.lowerBack.rawValue == "lowerBack")
    }

    @Test func defaultsAreSane() {
        #expect(Defaults.trainingDays.count == 3)
        #expect(Defaults.plates.allSatisfy { $0 > 0 })
        #expect((1.6...2.2).contains(Defaults.proteinPerKg))
        #expect((0.8...1.0).contains(Defaults.fatPerKg))
    }
}
