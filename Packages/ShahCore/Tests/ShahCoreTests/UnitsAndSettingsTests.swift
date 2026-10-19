import Foundation
import Testing
@testable import ShahCore

@Suite("Units and formatting")
struct UnitsTests {
    @Test func conversion() {
        #expect(DistanceUnit.kilometers.value(fromMeters: 7_400) == 7.4)
        #expect(abs(DistanceUnit.miles.value(fromMeters: 1_609.344) - 1) < 1e-12)
        #expect(abs(DistanceUnit.miles.value(fromMeters: 10_000) - 6.2137) < 1e-4)
        #expect(DistanceUnit.miles.meters(fromValue: 3) == 4_828.032)
    }

    @Test("Default unit follows the locale", arguments: [
        ("uk_UA", DistanceUnit.kilometers),
        ("de_DE", .kilometers),
        ("en_US", .miles),
        ("en_GB", .miles),
    ])
    func preferredUnit(identifier: String, expected: DistanceUnit) {
        #expect(DistanceUnit.preferred(for: Locale(identifier: identifier)) == expected)
    }

    @Test func localizedNumber() {
        #expect(DistanceFormat.number(meters: 7_400, unit: .kilometers, locale: Locale(identifier: "uk_UA")) == "7,4")
        #expect(DistanceFormat.number(meters: 7_400, unit: .kilometers, locale: Locale(identifier: "en_US")) == "7.4")
        #expect(DistanceFormat.number(meters: 0, unit: .kilometers, locale: Locale(identifier: "uk_UA")) == "0,0")
        #expect(DistanceFormat.number(meters: 7_436, unit: .kilometers, fractionDigits: 2, locale: Locale(identifier: "uk_UA")) == "7,44")
        #expect(DistanceFormat.number(meters: 10_000, unit: .miles, locale: Locale(identifier: "en_US")) == "6.2")
    }

    @Test func stepsUseGrouping() {
        let uk = DistanceFormat.steps(10_482, locale: Locale(identifier: "uk_UA"))
        #expect(uk.filter(\.isNumber) == "10482")
        #expect(uk.count == 6) // with a (non-breaking) space
        #expect(DistanceFormat.steps(10_482, locale: Locale(identifier: "en_US")) == "10,482")
    }

    @Test func percentNeverRoundsUpToTheGoal() {
        #expect(DistanceFormat.percent(0.74) == 74)
        #expect(DistanceFormat.percent(0.999) == 99)
        #expect(DistanceFormat.percent(1.24) == 124)
    }
}

@Suite("Settings")
struct SettingsTests {
    @Test func defaults() {
        let s = AppSettings()
        #expect(s.goalMeters == 5_000)
        #expect(s.unitOverride == nil)
        #expect(s.theme == .system)
        #expect(!s.hasCompletedOnboarding)
        #expect(s.unit(for: Locale(identifier: "uk_UA")) == .kilometers)
    }

    @Test func goalInMilesSnapsToStepper() {
        var s = AppSettings()
        #expect(s.goalValue(in: .kilometers) == 5)
        #expect(s.goalValue(in: .miles) == 3) // 3.107 → 3.0
        s.setGoal(value: 3.5, in: .miles)
        #expect(s.goalMeters == 5_632.704)
        s.setGoal(value: 0, in: .kilometers)
        #expect(s.goalMeters == 500) // clamped to 0.5
    }

    @Test func celebratesOncePerDay() {
        var s = AppSettings()
        let today = day(2026, 10, 18)
        #expect(!s.shouldCelebrate(goalMet: false, today: today))
        #expect(s.shouldCelebrate(goalMet: true, today: today))
        s.lastCelebratedDay = today
        #expect(!s.shouldCelebrate(goalMet: true, today: today))
        #expect(s.shouldCelebrate(goalMet: true, today: today.advanced(by: 1)))
    }

    @Test func storeRoundTripAndForwardCompatibility() throws {
        let defaults = UserDefaults(suiteName: "shah.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        #expect(store.load() == AppSettings())

        let custom = AppSettings(goalMeters: 8_000, unitOverride: .miles, theme: .dark, hasCompletedOnboarding: true, lastCelebratedDay: day(2026, 10, 18))
        store.save(custom)
        #expect(SettingsStore(defaults: defaults).load() == custom)

        // An older build that only knew the goal.
        defaults.set(Data(#"{"goalMeters":7000}"#.utf8), forKey: SettingsStore.key)
        #expect(store.load() == AppSettings(goalMeters: 7_000))
    }
}

@Suite("Widget snapshot")
struct WidgetSnapshotTests {
    let snapshot = WidgetSnapshot(
        day: day(2026, 10, 18), meters: 7_400, steps: 10_482, goalMeters: 10_000, unit: .kilometers,
        week: [1, 2, 3, 4, 5, 6, 7], updatedAt: date(2026, 10, 18, 23, 50)
    )

    @Test func sameDayIsUnchanged() {
        #expect(snapshot.asOf(date(2026, 10, 18, 23, 59), in: kyiv) == snapshot)
    }

    @Test func resetsAfterMidnight() {
        let next = snapshot.asOf(date(2026, 10, 19, 0, 1), in: kyiv)
        #expect(next.day == day(2026, 10, 19))
        #expect(next.meters == 0 && next.steps == 0)
        #expect(next.week == [2, 3, 4, 5, 6, 7, 0])
        #expect(snapshot.asOf(date(2026, 10, 30), in: kyiv).week == Array(repeating: 0, count: 7))
    }

    @Test func madeFromHistory() {
        let h = history(endingOn: day(2026, 10, 18), km: [6.1, 8.3, 4.2, 10.4, 7.9, 12.6, 7.4])
        let s = WidgetSnapshot.make(history: h, today: day(2026, 10, 18), settings: AppSettings(goalMeters: 10_000), unit: .kilometers, now: .now)
        #expect(s.meters == 7_400)
        #expect(s.week.count == 7 && s.week.last == 7_400 && s.week.first == 6_100)
        #expect(abs(s.progress - 0.74) < 1e-9)
    }
}
