import Foundation

/// On-disk form of the history cache.
public struct HistoryCache: Codable, Equatable, Sendable {
    /// Days were bucketed at midnight in this zone.
    public var timeZoneID: String
    /// Only days with data, sorted.
    public var days: [DayTotal]
    /// Every day up to and including this one has been fetched.
    public var syncedThrough: DayKey?
    public var updatedAt: Date?
    public var fullSyncAt: Date?

    public init(timeZoneID: String, days: [DayTotal], syncedThrough: DayKey?, updatedAt: Date?, fullSyncAt: Date?) {
        self.timeZoneID = timeZoneID
        self.days = days
        self.syncedThrough = syncedThrough
        self.updatedAt = updatedAt
        self.fullSyncAt = fullSyncAt
    }

    public var history: History {
        History(totals: Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { $1 }), timeZoneID: timeZoneID, updatedAt: updatedAt)
    }
}

/// Daily totals with a disk cache: the cached history is available instantly
/// at launch, and `refresh()` brings it up to date from Health.
///
/// - Incremental refresh re-reads the last week (plus any days missed while
///   the app was closed), so late Apple Watch syncs and edits are picked up.
/// - A full refresh re-reads everything since `earliestDay`. It runs on first
///   launch, after a time-zone change (all days must be re-bucketed at the new
///   midnight) and at most once per `fullSyncInterval`.
/// - Concurrent refreshes (two observer queries firing together) share one fetch.
public actor DistanceRepository {
    public enum RefreshKind: Sendable {
        case incremental
        case full
    }

    public static let defaultEarliestDay = DayKey(year: 2014, month: 9, day: 1) // Health app launch
    static let incrementalDays = 8
    static let maxIncrementalGap = 400

    private let health: any HealthService
    private let cache: any ValueStore<HistoryCache>
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let earliestDay: DayKey
    private let fullSyncInterval: TimeInterval

    private var state: HistoryCache?
    private var inFlight: Task<History, any Error>?

    public init(
        health: any HealthService,
        cache: any ValueStore<HistoryCache>,
        timeZone: @escaping @Sendable () -> TimeZone = { .current },
        now: @escaping @Sendable () -> Date = { Date() },
        earliestDay: DayKey = DistanceRepository.defaultEarliestDay,
        fullSyncInterval: TimeInterval = 24 * 3600
    ) {
        self.health = health
        self.cache = cache
        self.timeZone = timeZone
        self.now = now
        self.earliestDay = earliestDay
        self.fullSyncInterval = fullSyncInterval
        self.state = cache.load()
    }

    /// Whatever is cached — possibly stale or bucketed in another time zone.
    public var history: History {
        state?.history ?? .empty(timeZoneID: timeZone().identifier)
    }

    public var needsFullSync: Bool {
        guard let state, let fullSyncAt = state.fullSyncAt else { return true }
        return state.timeZoneID != timeZone().identifier || now().timeIntervalSince(fullSyncAt) >= fullSyncInterval
    }

    @discardableResult
    public func refresh(_ kind: RefreshKind = .incremental) async throws -> History {
        if let inFlight { return try await inFlight.value }
        let task = Task { try await self.performRefresh(kind) }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    /// Runs a full refresh only when one is due.
    @discardableResult
    public func fullSyncIfNeeded() async throws -> History {
        needsFullSync ? try await refresh(.full) : history
    }

    private func performRefresh(_ kind: RefreshKind) async throws -> History {
        let zone = timeZone()
        let today = DayKey(now(), in: zone)

        var from = earliestDay
        var isFull = true
        if kind == .incremental, let state, state.fullSyncAt != nil, state.timeZoneID == zone.identifier {
            let lastSynced = state.syncedThrough ?? today
            let candidate = min(lastSynced.advanced(by: -1), today.advanced(by: -(Self.incrementalDays - 1)))
            if candidate.days(to: today) <= Self.maxIncrementalGap {
                from = max(candidate, earliestDay)
                isFull = false
            }
        }

        let fetched = try await health.dailyTotals(from: from, through: today, timeZone: zone)

        // The fetched window replaces what was cached for it, so samples deleted
        // in Health disappear here too.
        var totals: [DayKey: DayTotal] = [:]
        if !isFull, let state {
            for day in state.days where day.day < from { totals[day.day] = day }
        }
        for day in fetched where day.day >= from && day.day <= today {
            var merged = totals[day.day] ?? .zero(day.day)
            merged.meters += day.meters
            merged.steps += day.steps
            totals[day.day] = merged
        }

        let timestamp = now()
        let newState = HistoryCache(
            timeZoneID: zone.identifier,
            days: totals.values.filter(\.hasData).sorted { $0.day < $1.day },
            syncedThrough: today,
            updatedAt: timestamp,
            fullSyncAt: isFull ? timestamp : state?.fullSyncAt
        )
        state = newState
        try? cache.save(newState)
        return newState.history
    }
}
