import Foundation
import ShahCore
import Testing
@testable import Shah

@MainActor
struct AppModelTests {
    let today = DayKey(Date(), in: .current)

    func makeModel(health: MockHealthService, settings: AppSettings = AppSettings(goalMeters: 10_000, hasCompletedOnboarding: true))
        -> (AppModel, InMemoryStore<WidgetSnapshot>) {
        let snapshots = InMemoryStore<WidgetSnapshot>()
        let store = SettingsStore(defaults: UserDefaults(suiteName: "tests.\(UUID().uuidString)")!)
        store.save(settings)
        let model = AppModel(
            health: health,
            repository: DistanceRepository(health: health, cache: InMemoryStore<HistoryCache>()),
            initialHistory: .empty(),
            settingsStore: store,
            snapshotStore: snapshots
        )
        return (model, snapshots)
    }

    @Test func refreshShowsTodayAndFeedsTheWidget() async {
        let (model, snapshots) = makeModel(health: .sample(today: today, days: 10))
        #expect(model.status == .loading)
        await model.refresh()
        #expect(model.status == .ready)
        #expect(model.summary.meters == 7_400)
        #expect(snapshots.load()?.meters == 7_400)
        #expect(snapshots.load()?.goalMeters == 10_000)
    }

    @Test func deviceWithoutHealth() async {
        let (model, _) = makeModel(health: MockHealthService(available: false))
        #expect(model.status == .healthUnavailable)
        await model.refresh()
        #expect(model.status == .healthUnavailable)
    }

    @Test func noDataScreenWhenHealthIsEmpty() async {
        let (model, _) = makeModel(health: MockHealthService())
        await model.refresh()
        #expect(model.hasNoData)
    }

    @Test func celebratesOnlyOncePerDayAndOnlyOnScreen() async {
        let health = MockHealthService(totals: [DayTotal(day: today, meters: 12_000, steps: 15_000)])
        let (model, _) = makeModel(health: health)

        await model.refresh()
        #expect(model.celebrationTrigger == 0) // in background: nobody would see it

        model.isInForeground = true
        await model.refresh()
        #expect(model.celebrationTrigger == 1)
        await model.refresh()
        #expect(model.celebrationTrigger == 1)
        #expect(model.settings.lastCelebratedDay == today)
    }

    @Test func goalChangeIsPersistedAndPublished() async {
        let (model, snapshots) = makeModel(health: .sample(today: today, days: 3))
        await model.refresh()
        model.updateSettings { $0.setGoal(value: 8, in: .kilometers) }
        #expect(model.settings.goalMeters == 8_000)
        #expect(snapshots.load()?.goalMeters == 8_000)
    }
}
