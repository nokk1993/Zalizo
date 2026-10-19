import Foundation

/// Bi-weekly calorie correction based on the 7-day moving average of body weight.
/// The result is only a proposal — the user confirms it with a button.
public enum AdaptiveCalories {
    public static let checkIntervalDays = 14
    /// Gain below this (% body weight / week) is considered too slow.
    public static let slowThresholdPercent = 0.1

    public static func fastThresholdPercent(_ experience: ExperienceLevel) -> Double {
        experience.isNovice ? 0.75 : 0.5
    }

    public enum Reason: Equatable, Sendable {
        /// Weight is going down or flat.
        case losing
        case tooSlow
        case tooFast
    }

    public struct Proposal: Equatable, Sendable {
        public let deltaKcal: Int
        public let weeklyGainPercent: Double
        public let reason: Reason
    }

    public enum Evaluation: Equatable, Sendable {
        /// Fewer than 14 days since the last check, or not enough weigh-ins.
        case notDue
        case notEnoughData
        case onTrack(weeklyGainPercent: Double)
        case adjust(Proposal)
    }

    /// - Parameters:
    ///   - lastCheck: date of the previous proposal (accepted or declined); nil → first check.
    public static func evaluate(
        samples: [WeightSample], experience: ExperienceLevel, goal: TrainingGoal,
        lastCheck: Date?, now: Date = .now, calendar: Calendar = .current
    ) -> Evaluation {
        guard goal == .muscleGain else { return .notDue }
        if let lastCheck, let due = calendar.date(byAdding: .day, value: checkIntervalDays, to: lastCheck), now < due {
            return .notDue
        }
        let recent = samples.filter { $0.date <= now }
        let days = WeightTrend.dailyAverages(recent, calendar: calendar)
        guard let first = days.first, let last = days.last,
              last.date.timeIntervalSince(first.date) >= Double(checkIntervalDays - 1) * 86_400,
              days.count >= 8,
              let weeklyKg = WeightTrend.weeklyChangeKg(recent, overDays: checkIntervalDays, calendar: calendar),
              let currentAverage = WeightTrend.movingAverage(recent, calendar: calendar).last?.weightKg,
              currentAverage > 0
        else { return .notEnoughData }

        let percent = weeklyKg / currentAverage * 100
        if percent < 0 {
            return .adjust(Proposal(deltaKcal: 200, weeklyGainPercent: percent, reason: .losing))
        }
        if percent < slowThresholdPercent {
            return .adjust(Proposal(deltaKcal: 150, weeklyGainPercent: percent, reason: .tooSlow))
        }
        if percent > fastThresholdPercent(experience) {
            return .adjust(Proposal(deltaKcal: -150, weeklyGainPercent: percent, reason: .tooFast))
        }
        return .onTrack(weeklyGainPercent: percent)
    }
}
