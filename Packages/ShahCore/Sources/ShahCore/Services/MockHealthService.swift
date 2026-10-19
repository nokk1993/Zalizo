import Foundation

/// In-memory `HealthService` for SwiftUI previews, UI tests and unit tests.
public final class MockHealthService: HealthService, @unchecked Sendable {
    private let lock = NSLock()
    private var _totals: [DayKey: DayTotal]
    private var _available: Bool
    private var _error: HealthError?
    private var _requests: [ClosedRange<DayKey>] = []
    private var _authorizationRequests = 0
    private let delay: Duration

    public init(totals: [DayTotal] = [], available: Bool = true, delay: Duration = .zero) {
        self._totals = Dictionary(totals.map { ($0.day, $0) }, uniquingKeysWith: { $1 })
        self._available = available
        self.delay = delay
    }

    // MARK: Test controls

    public var totals: [DayTotal] {
        get { lock.withLock { _totals.values.sorted { $0.day < $1.day } } }
        set { lock.withLock { _totals = Dictionary(newValue.map { ($0.day, $0) }, uniquingKeysWith: { $1 }) } }
    }

    public func set(_ day: DayKey, meters: Double, steps: Int = 0) {
        lock.withLock { _totals[day] = DayTotal(day: day, meters: meters, steps: steps) }
    }

    public func remove(_ day: DayKey) {
        lock.withLock { _totals[day] = nil }
    }

    /// Every error thrown by `dailyTotals` until reset to `nil`.
    public var error: HealthError? {
        get { lock.withLock { _error } }
        set { lock.withLock { _error = newValue } }
    }

    /// Ranges requested from `dailyTotals`, in call order.
    public var requests: [ClosedRange<DayKey>] { lock.withLock { _requests } }
    public var authorizationRequests: Int { lock.withLock { _authorizationRequests } }

    // MARK: HealthService

    public var isHealthDataAvailable: Bool { lock.withLock { _available } }

    public func requestAuthorization() async throws {
        guard isHealthDataAvailable else { throw HealthError.unavailable }
        lock.withLock { _authorizationRequests += 1 }
    }

    public func dailyTotals(from start: DayKey, through end: DayKey, timeZone: TimeZone) async throws -> [DayTotal] {
        lock.withLock { _requests.append(start...end) }
        if delay > .zero { try await Task.sleep(for: delay) }
        guard isHealthDataAvailable else { throw HealthError.unavailable }
        if let error { throw error }
        return lock.withLock { _totals.values.filter { $0.day >= start && $0.day <= end }.sorted { $0.day < $1.day } }
    }
}

extension MockHealthService {
    /// Plausible history for previews: `days` days ending `today`, today = 7.4 km.
    public static func sample(today: DayKey, days: Int = 400) -> MockHealthService {
        let pattern: [Double] = [6.1, 8.3, 4.2, 10.4, 7.9, 12.6, 6.2, 9.1, 5.5, 11.2, 3.8, 8.8, 10.9, 7.0]
        let totals = (0..<days).map { offset -> DayTotal in
            let day = today.advanced(by: -offset)
            let km = offset == 0 ? 7.4 : pattern[offset % pattern.count]
            return DayTotal(day: day, meters: km * 1000, steps: Int(km * 1_416))
        }
        return MockHealthService(totals: totals)
    }
}
