import Foundation

public enum HealthError: Error, Equatable, Sendable {
    /// `HKHealthStore.isHealthDataAvailable() == false` (e.g. iPad without Health).
    case unavailable
    /// The device is locked and Health data is encrypted (widgets, background).
    case protectedDataLocked
}

/// Read-only access to daily distance and steps.
///
/// Implementations must return totals that are already de-duplicated across
/// sources (iPhone + Apple Watch). The HealthKit implementation gets this from
/// `HKStatisticsCollectionQuery` with `.cumulativeSum`; raw samples are never summed.
public protocol HealthService: Sendable {
    var isHealthDataAvailable: Bool { get }

    /// Shows the system permission sheet (only the first time).
    /// HealthKit never reveals whether *read* access was denied: denied looks
    /// exactly like "no data", which the UI has to explain.
    func requestAuthorization() async throws

    /// Totals for each day from `start` through `end` (inclusive), with day
    /// boundaries at local midnight in `timeZone`. Days without data may be omitted.
    func dailyTotals(from start: DayKey, through end: DayKey, timeZone: TimeZone) async throws -> [DayTotal]
}
