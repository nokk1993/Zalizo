import Foundation
import HealthKit

/// Optional Apple Health sync (body weight both ways, strength workouts out).
/// Requires the HealthKit capability on the app target (Signing & Capabilities → + Capability → HealthKit).
/// It is off by default so the app always signs with a free Personal Team.
@MainActor
enum HealthService {
    static let enabledKey = "healthSyncEnabled"
    private static let store = HKHealthStore()

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    enum HealthError: LocalizedError {
        case unavailable
        case notAuthorized(String)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                String(localized: "Apple Health недоступний на цьому пристрої.")
            case .notAuthorized(let details):
                String(localized: "Не вдалося підключити Apple Health. Увімкни в Xcode: таргет Zalizo → Signing & Capabilities → + Capability → HealthKit, і знову натисни Run. Деталі: \(details)")
            }
        }
    }

    static func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        let bodyMass = HKQuantityType(.bodyMass)
        do {
            try await store.requestAuthorization(toShare: [bodyMass, HKObjectType.workoutType()], read: [bodyMass])
        } catch {
            throw HealthError.notAuthorized(error.localizedDescription)
        }
    }

    static func saveWeight(_ kg: Double, date: Date) {
        guard isEnabled, isAvailable else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass), quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date, end: date
        )
        Task {
            do {
                try await store.save(sample)
            } catch {
                Log.data.error("Health weight save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func saveWorkout(start: Date, end: Date) {
        guard isEnabled, isAvailable, end > start else { return }
        Task {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .traditionalStrengthTraining
            configuration.locationType = .indoor
            let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
            do {
                try await builder.beginCollection(at: start)
                try await builder.endCollection(at: end)
                _ = try await builder.finishWorkout()
            } catch {
                Log.data.error("Health workout save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Body-weight samples from Health (e.g. smart scales) since `date`.
    static func weights(since date: Date) async throws -> [(date: Date, kg: Double)] {
        guard isAvailable else { throw HealthError.unavailable }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass), predicate: HKQuery.predicateForSamples(withStart: date, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store).map { ($0.startDate, $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
    }
}
