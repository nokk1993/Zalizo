#if canImport(HealthKit)
import Foundation
import HealthKit

/// `HealthService` backed by HealthKit. Read-only.
public final class HealthKitService: HealthService, @unchecked Sendable {
    private let store = HKHealthStore()
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    private let stepType = HKQuantityType(.stepCount)

    public init() {}

    private var readTypes: Set<HKObjectType> { [distanceType, stepType] }

    public var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async throws {
        guard isHealthDataAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    public func dailyTotals(from start: DayKey, through end: DayKey, timeZone: TimeZone) async throws -> [DayTotal] {
        guard isHealthDataAvailable else { throw HealthError.unavailable }
        async let meters = dailySums(of: distanceType, unit: .meter(), from: start, through: end, timeZone: timeZone)
        async let steps = dailySums(of: stepType, unit: .count(), from: start, through: end, timeZone: timeZone)
        let (m, s) = try await (meters, steps)
        return Set(m.keys).union(s.keys).sorted().map { day in
            DayTotal(day: day, meters: m[day] ?? 0, steps: Int((s[day] ?? 0).rounded()))
        }
    }

    /// One `HKStatisticsCollectionQuery` with `.cumulativeSum`, 1-day buckets
    /// anchored at local midnight. HealthKit merges overlapping samples from
    /// iPhone and Apple Watch by source priority, so the sum equals the number
    /// the Health app shows.
    private func dailySums(of type: HKQuantityType, unit: HKUnit, from start: DayKey, through end: DayKey, timeZone: TimeZone) async throws -> [DayKey: Double] {
        let startDate = start.startDate(in: timeZone)
        let endDate = end.advanced(by: 1).startDate(in: timeZone)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate)),
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        let collection: HKStatisticsCollection
        do {
            collection = try await descriptor.result(for: store)
        } catch let error as HKError where error.code == .errorNoData {
            return [:]
        } catch let error as HKError where error.code == .errorDatabaseInaccessible {
            throw HealthError.protectedDataLocked
        }
        var sums: [DayKey: Double] = [:]
        for statistics in collection.statistics() {
            guard let quantity = statistics.sumQuantity() else { continue }
            sums[DayKey(statistics.startDate, in: timeZone), default: 0] += quantity.doubleValue(for: unit)
        }
        return sums
    }

    // MARK: Live updates

    /// Starts long-running observer queries for distance and steps. `onChange`
    /// runs on every new sample, also when HealthKit wakes the app in the
    /// background; HealthKit is told the update was handled only after it returns.
    public func startObserving(onChange: @escaping @Sendable () async -> Void) {
        for type in [distanceType, stepType] {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                // HealthKit's completion handler is not annotated Sendable.
                nonisolated(unsafe) let done = completion
                guard error == nil else {
                    done()
                    return
                }
                Task {
                    await onChange()
                    done()
                }
            }
            store.execute(query)
        }
    }

    /// Asks HealthKit to wake the app when new samples arrive. iOS may deliver
    /// some types (steps) at most hourly regardless of the requested frequency.
    public func enableBackgroundDelivery() async {
        for type in [distanceType, stepType] {
            // Fails without the background-delivery entitlement; the app then
            // just refreshes in the foreground and from widget timelines.
            try? await store.enableBackgroundDelivery(for: type, frequency: .immediate)
        }
    }
}
#endif
