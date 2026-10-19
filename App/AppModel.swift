import Foundation
import Observation
import ShahCore
import WidgetKit

/// App-wide state: settings, the daily history and refreshing it from Health.
@Observable
final class AppModel {
    enum Status: Equatable {
        /// Nothing cached yet and the first fetch is running.
        case loading
        case ready
        /// `HKHealthStore.isHealthDataAvailable() == false`.
        case healthUnavailable
    }

    private(set) var history: History
    private(set) var settings: AppSettings
    private(set) var status: Status
    private(set) var today: DayKey
    private(set) var isRefreshing = false
    /// Incremented the first time per day the goal is seen as met while the
    /// app is on screen; views play the celebration when it changes.
    private(set) var celebrationTrigger = 0
    var isInForeground = false

    let health: any HealthService
    private let repository: DistanceRepository
    private let settingsStore: SettingsStore
    private let snapshotStore: any ValueStore<WidgetSnapshot>
    private let clock: @Sendable () -> Date
    private let locale: Locale

    init(
        health: any HealthService,
        repository: DistanceRepository,
        initialHistory: History,
        settingsStore: SettingsStore,
        snapshotStore: any ValueStore<WidgetSnapshot>,
        clock: @escaping @Sendable () -> Date = { Date() },
        locale: Locale = .current
    ) {
        self.health = health
        self.repository = repository
        self.history = initialHistory
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        self.snapshotStore = snapshotStore
        self.clock = clock
        self.locale = locale
        self.today = DayKey(clock(), in: .current)
        if !health.isHealthDataAvailable {
            status = .healthUnavailable
        } else {
            status = initialHistory.updatedAt == nil ? .loading : .ready
        }
    }

    // MARK: Derived

    var unit: DistanceUnit { settings.unit(for: locale) }

    var summary: TodaySummary {
        Insights.today(today, history: history, goalMeters: settings.goalMeters)
    }

    var streak: Streak {
        Insights.streak(through: today, history: history, goalMeters: settings.goalMeters)
    }

    /// Synced, but Health returned nothing at all: no data yet, or read access denied
    /// (HealthKit does not tell which).
    var hasNoData: Bool {
        status == .ready && history.isEmpty
    }

    // MARK: Actions

    func refresh() async {
        guard health.isHealthDataAvailable else {
            status = .healthUnavailable
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        today = DayKey(clock(), in: .current)
        do {
            history = try await repository.refresh()
            status = .ready
            didUpdateHistory()
            // Re-reads all history at most once a day or after a time-zone change.
            history = try await repository.fullSyncIfNeeded()
            didUpdateHistory()
        } catch {
            // Locked device or a transient HealthKit error: keep showing the cache.
            if status == .loading, history.updatedAt == nil {
                status = .ready
            }
        }
    }

    func requestAuthorization() async {
        try? await health.requestAuthorization()
        await refresh()
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        settingsStore.save(settings)
        publishWidgetSnapshot()
    }

    /// Midnight passed, the clock was changed or the time zone changed.
    func handleClockChange() {
        NSTimeZone.resetSystemTimeZone()
        today = DayKey(clock(), in: .current)
        Task { await refresh() }
    }

    /// Long-running HealthKit observers + background delivery, so new
    /// samples refresh the cache and widgets even while the app is closed.
    func startHealthObservation() {
        #if canImport(HealthKit)
        guard let healthKit = health as? HealthKitService else { return }
        healthKit.startObserving { [weak self] in
            await self?.refresh()
        }
        Task { await healthKit.enableBackgroundDelivery() }
        #endif
    }

    // MARK: Private

    private func didUpdateHistory() {
        publishWidgetSnapshot()
        if isInForeground, settings.shouldCelebrate(goalMet: summary.isGoalMet, today: today) {
            updateSettings { $0.lastCelebratedDay = today }
            celebrationTrigger += 1
        }
    }

    private func publishWidgetSnapshot() {
        let snapshot = WidgetSnapshot.make(history: history, today: today, settings: settings, unit: unit, now: clock())
        let previous = snapshotStore.load()
        try? snapshotStore.save(snapshot)
        // Background reloads count against the widget budget: only ask when
        // something visible changed.
        if previous.map({ !$0.looksSame(as: snapshot) }) ?? true {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

private extension WidgetSnapshot {
    func looksSame(as other: WidgetSnapshot) -> Bool {
        func shown(_ meters: Double) -> Double { DistanceFormat.rounded(meters: meters, unit: unit) }
        return day == other.day && unit == other.unit && goalMeters == other.goalMeters
            && shown(meters) == shown(other.meters) && steps / 100 == other.steps / 100
            && week.map(shown) == other.week.map(shown)
    }
}

// MARK: - Factories

extension AppModel {
    static let uiTestArgument = "-uiTestMockHealth"
    static let uiTestSkipOnboardingArgument = "-uiTestSkipOnboarding"

    static func live() -> AppModel {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(uiTestArgument) {
            return preview(settings: AppSettings(goalMeters: 10_000, hasCompletedOnboarding: arguments.contains(uiTestSkipOnboardingArgument)))
        }
        let health: any HealthService
        #if canImport(HealthKit)
        health = HealthKitService()
        #else
        health = MockHealthService(available: false)
        #endif
        let cache = JSONFileStore<HistoryCache>(url: SharedContainer.historyCacheURL)
        return AppModel(
            health: health,
            repository: DistanceRepository(health: health, cache: cache),
            initialHistory: cache.load()?.history ?? .empty(),
            settingsStore: SettingsStore(defaults: SharedContainer.defaults),
            snapshotStore: JSONFileStore<WidgetSnapshot>(url: SharedContainer.widgetSnapshotURL)
        )
    }

    /// In-memory model for previews and UI tests.
    static func preview(
        days: Int = 400,
        available: Bool = true,
        settings: AppSettings = AppSettings(goalMeters: 10_000, hasCompletedOnboarding: true)
    ) -> AppModel {
        let today = DayKey(Date(), in: .current)
        let totals = days > 0 ? MockHealthService.sample(today: today, days: days).totals : []
        let health = MockHealthService(totals: totals, available: available)
        let store = SettingsStore(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)")!)
        store.save(settings)
        return AppModel(
            health: health,
            repository: DistanceRepository(health: health, cache: InMemoryStore<HistoryCache>()),
            initialHistory: .empty(),
            settingsStore: store,
            snapshotStore: InMemoryStore<WidgetSnapshot>()
        )
    }
}
