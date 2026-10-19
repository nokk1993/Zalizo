import Foundation

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// User preferences shared by the app and the widgets (via the App Group).
public struct AppSettings: Codable, Equatable, Sendable {
    public static let defaultGoalMeters: Double = 5000
    /// Goal stepper bounds and step, in the display unit.
    public static let goalRange: ClosedRange<Double> = 0.5...100
    public static let goalStep: Double = 0.5

    public var goalMeters: Double
    /// `nil` follows the device locale.
    public var unitOverride: DistanceUnit?
    public var theme: AppTheme
    public var hasCompletedOnboarding: Bool
    public var lastCelebratedDay: DayKey?

    public init(
        goalMeters: Double = AppSettings.defaultGoalMeters,
        unitOverride: DistanceUnit? = nil,
        theme: AppTheme = .system,
        hasCompletedOnboarding: Bool = false,
        lastCelebratedDay: DayKey? = nil
    ) {
        self.goalMeters = goalMeters
        self.unitOverride = unitOverride
        self.theme = theme
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastCelebratedDay = lastCelebratedDay
    }

    public func unit(for locale: Locale = .current) -> DistanceUnit {
        unitOverride ?? .preferred(for: locale)
    }

    /// The celebration plays once per day, the first time the goal is seen as met.
    public func shouldCelebrate(goalMet: Bool, today: DayKey) -> Bool {
        goalMet && lastCelebratedDay != today
    }

    /// Goal value in `unit`, snapped to the stepper grid.
    public func goalValue(in unit: DistanceUnit) -> Double {
        let value = unit.value(fromMeters: goalMeters)
        return (value / Self.goalStep).rounded() * Self.goalStep
    }

    public mutating func setGoal(value: Double, in unit: DistanceUnit) {
        let clamped = min(max(value, Self.goalRange.lowerBound), Self.goalRange.upperBound)
        goalMeters = unit.meters(fromValue: clamped)
    }
}

extension AppSettings {
    // Decoding tolerates missing keys so that adding a setting never resets the others.
    private enum CodingKeys: String, CodingKey {
        case goalMeters, unitOverride, theme, hasCompletedOnboarding, lastCelebratedDay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            goalMeters: try c.decodeIfPresent(Double.self, forKey: .goalMeters) ?? Self.defaultGoalMeters,
            unitOverride: try c.decodeIfPresent(DistanceUnit.self, forKey: .unitOverride),
            theme: try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system,
            hasCompletedOnboarding: try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false,
            lastCelebratedDay: try c.decodeIfPresent(DayKey.self, forKey: .lastCelebratedDay)
        )
    }
}
