import Foundation
import Testing
@testable import ShahCore

@Suite("DistanceRepository")
struct RepositoryTests {
    let earliest = day(2026, 1, 1)

    func makeRepository(_ health: MockHealthService, cache: InMemoryStore<HistoryCache> = .init(), clock: TestClock) -> DistanceRepository {
        DistanceRepository(
            health: health, cache: cache,
            timeZone: { clock.zone }, now: { clock.now },
            earliestDay: earliest
        )
    }

    @Test func firstRefreshIsFullAndCached() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let health = MockHealthService.sample(today: day(2026, 10, 18), days: 30)
        let cache = InMemoryStore<HistoryCache>()
        let repo = makeRepository(health, cache: cache, clock: clock)

        #expect(await repo.history.isEmpty)
        let h = try await repo.refresh()
        #expect(health.requests == [earliest...day(2026, 10, 18)])
        #expect(h[day(2026, 10, 18)].meters == 7_400)
        #expect(h.firstDataDay == day(2026, 9, 19))
        #expect(cache.load()?.days.count == 30)

        // A new launch shows the cached numbers before touching Health.
        let relaunched = makeRepository(health, cache: cache, clock: clock)
        #expect(await relaunched.history[day(2026, 10, 18)].meters == 7_400)
        #expect(health.requests.count == 1)
    }

    @Test func laterRefreshesOnlyReadTheLastWeek() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let health = MockHealthService.sample(today: day(2026, 10, 18), days: 30)
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh()

        health.set(day(2026, 10, 18), meters: 9_000)
        clock.now = date(2026, 10, 18, 18)
        let h = try await repo.refresh()
        #expect(health.requests.last == day(2026, 10, 11)...day(2026, 10, 18))
        #expect(h[day(2026, 10, 18)].meters == 9_000)
        #expect(h[day(2026, 9, 20)].meters > 0) // older days kept from the cache
    }

    @Test func dayRolloverWhileOpen() async throws {
        let clock = TestClock(date(2026, 10, 18, 23, 59))
        let health = MockHealthService(totals: [DayTotal(day: day(2026, 10, 18), meters: 7_400, steps: 10_000)])
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh()

        clock.now = date(2026, 10, 19, 0, 1)
        health.set(day(2026, 10, 19), meters: 50)
        let h = try await repo.refresh()
        let today = DayKey(clock.now, in: clock.zone)
        #expect(today == day(2026, 10, 19))
        #expect(h[today].meters == 50)
        #expect(h[day(2026, 10, 18)].meters == 7_400)
    }

    @Test func catchesUpAfterDaysClosed() async throws {
        let clock = TestClock(date(2026, 10, 1, 9))
        let health = MockHealthService.sample(today: day(2026, 10, 18), days: 60)
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh()

        clock.now = date(2026, 10, 18, 9)
        let h = try await repo.refresh()
        #expect(health.requests.last == day(2026, 9, 30)...day(2026, 10, 18))
        #expect(h[day(2026, 10, 10)].meters > 0)
    }

    @Test func deletionsInHealthAreReflected() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let health = MockHealthService.sample(today: day(2026, 10, 18), days: 10)
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh()

        health.remove(day(2026, 10, 16))
        let h = try await repo.refresh()
        #expect(h[day(2026, 10, 16)].meters == 0)
    }

    @Test func timeZoneChangeTriggersFullRebucketing() async throws {
        let clock = TestClock(date(2026, 10, 18, 9), zone: kyiv)
        let health = MockHealthService.sample(today: day(2026, 10, 18), days: 10)
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh()
        #expect(await !repo.needsFullSync)

        // Fly to New York: same instant, different calendar day and midnights.
        clock.zone = newYork
        #expect(await repo.needsFullSync)
        let h = try await repo.refresh()
        #expect(health.requests.last == earliest...day(2026, 10, 18))
        #expect(h.timeZoneID == "America/New_York")
        #expect(await !repo.needsFullSync)
    }

    @Test func fullSyncIsDueOncePerDay() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let health = MockHealthService.sample(today: day(2026, 10, 18), days: 10)
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh()
        try await repo.fullSyncIfNeeded()
        #expect(health.requests.count == 1)

        clock.now = date(2026, 10, 19, 9, 1)
        try await repo.fullSyncIfNeeded()
        #expect(health.requests.count == 2)
        #expect(health.requests.last?.lowerBound == earliest)
    }

    @Test func concurrentRefreshesShareOneFetch() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let health = MockHealthService(totals: [DayTotal(day: day(2026, 10, 18), meters: 1_000, steps: 1)], delay: .milliseconds(100))
        let repo = makeRepository(health, clock: clock)
        async let a = repo.refresh()
        async let b = repo.refresh()
        let (ha, hb) = try await (a, b)
        #expect(ha == hb)
        #expect(health.requests.count == 1)
    }

    @Test func fullRequestDuringIncrementalStillRunsFull() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let health = MockHealthService(totals: [DayTotal(day: day(2026, 10, 18), meters: 1_000, steps: 1)], delay: .milliseconds(100))
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh(.full)
        let before = health.requests.count

        // Access was just granted while a routine refresh was running.
        async let routine = repo.refresh(.incremental)
        try await Task.sleep(for: .milliseconds(20))
        async let afterGrant = repo.refresh(.full)
        _ = try await (routine, afterGrant)
        let requests = Array(health.requests.dropFirst(before))
        #expect(requests.count == 2)
        #expect(requests.last?.lowerBound == earliest)
    }

    @Test func unavailableHealthKeepsCache() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let health = MockHealthService.sample(today: day(2026, 10, 18), days: 5)
        let repo = makeRepository(health, clock: clock)
        try await repo.refresh()

        health.error = .protectedDataLocked
        await #expect(throws: HealthError.protectedDataLocked) { try await repo.refresh() }
        #expect(await repo.history[day(2026, 10, 18)].meters == 7_400)
    }

    @Test func deviceWithoutHealth() async {
        let clock = TestClock(date(2026, 10, 18, 9))
        let repo = makeRepository(MockHealthService(available: false), clock: clock)
        await #expect(throws: HealthError.unavailable) { try await repo.refresh() }
        #expect(await repo.history.isEmpty)
    }

    @Test func firstLaunchWithoutAnyData() async throws {
        let clock = TestClock(date(2026, 10, 18, 9))
        let repo = makeRepository(MockHealthService(), clock: clock)
        let h = try await repo.refresh()
        #expect(h.isEmpty)
        #expect(h.updatedAt != nil) // synced, just nothing there → "Немає даних" screen
    }

    @Test func fileStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shah-\(UUID().uuidString)/history.json")
        let store = JSONFileStore<HistoryCache>(url: url)
        #expect(store.load() == nil)
        let cache = HistoryCache(timeZoneID: "Europe/Kyiv", days: [DayTotal(day: day(2026, 10, 18), meters: 7_400, steps: 10_482)],
                                 syncedThrough: day(2026, 10, 18), updatedAt: date(2026, 10, 18), fullSyncAt: date(2026, 10, 18))
        try store.save(cache)
        #expect(store.load() == cache)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
