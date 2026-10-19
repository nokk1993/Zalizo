import Foundation

/// A dated body-weight sample (value type mirror of the SwiftData entry).
public struct WeightSample: Equatable, Sendable {
    public let date: Date
    public let weightKg: Double

    public init(date: Date, weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}

/// Weight trend, target pace and forecast.
///
/// Rate guidance: Iraki et al., 2019 and Helms et al. (Muscle & Strength Pyramid):
/// novices ~0.25–0.5 % of body weight per week, trained lifters ≤0.25 %/week.
public enum WeightTrend {
    // MARK: Moving average

    /// Daily series with a trailing 7-day moving average. Several samples on one day are averaged first.
    public static func movingAverage(_ samples: [WeightSample], windowDays: Int = 7, calendar: Calendar = .current) -> [WeightSample] {
        let daily = dailyAverages(samples, calendar: calendar)
        guard !daily.isEmpty else { return [] }
        var result: [WeightSample] = []
        result.reserveCapacity(daily.count)
        for (index, day) in daily.enumerated() {
            guard let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: day.date) else { continue }
            let window = daily[...index].filter { $0.date >= windowStart }
            let mean = window.reduce(0) { $0 + $1.weightKg } / Double(window.count)
            result.append(WeightSample(date: day.date, weightKg: mean))
        }
        return result
    }

    /// One sample per calendar day (start of day), sorted by date.
    public static func dailyAverages(_ samples: [WeightSample], calendar: Calendar = .current) -> [WeightSample] {
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { day, items in WeightSample(date: day, weightKg: items.reduce(0) { $0 + $1.weightKg } / Double(items.count)) }
            .sorted { $0.date < $1.date }
    }

    /// Average weekly change of the 7-day moving average between the last sample and the one `days` earlier.
    /// Returns kg/week, or nil if there is not enough data.
    public static func weeklyChangeKg(_ samples: [WeightSample], overDays days: Int = 14, calendar: Calendar = .current) -> Double? {
        let averaged = movingAverage(samples, calendar: calendar)
        guard let last = averaged.last,
              let anchorDate = calendar.date(byAdding: .day, value: -days, to: last.date),
              let anchor = averaged.last(where: { $0.date <= anchorDate }) else { return nil }
        let spanDays = last.date.timeIntervalSince(anchor.date) / 86_400
        guard spanDays >= 7 else { return nil }
        return (last.weightKg - anchor.weightKg) / spanDays * 7
    }

    // MARK: Pace

    /// Recommended gain range, % of body weight per week.
    public static func recommendedRatePercent(_ experience: ExperienceLevel) -> ClosedRange<Double> {
        switch experience {
        case .beginner: 0.25...0.5
        case .intermediate: 0.15...0.25
        case .advanced: 0.1...0.25
        }
    }

    /// Default target pace used for the forecast, % of body weight per week.
    public static func targetRatePercent(_ experience: ExperienceLevel) -> Double {
        switch experience {
        case .beginner: 0.4
        case .intermediate: 0.25
        case .advanced: 0.2
        }
    }

    public static func targetRateKgPerWeek(weightKg: Double, experience: ExperienceLevel) -> Double {
        weightKg * targetRatePercent(experience) / 100
    }

    /// Suggested target weight when the user did not set one: one 16-week gaining block at the target pace,
    /// capped at BMI 27, rounded to 0.5 kg.
    public static func suggestedTargetWeight(weightKg: Double, heightCm: Double, experience: ExperienceLevel) -> Double {
        let gain = targetRateKgPerWeek(weightKg: weightKg, experience: experience) * 16
        let meters = heightCm / 100
        let bmiCap = 27 * meters * meters
        let target = min(weightKg + gain, max(bmiCap, weightKg + 1))
        return (target * 2).rounded() / 2
    }

    // MARK: Forecast

    public struct Forecast: Equatable, Sendable {
        public let weeks: Double
        public let targetDate: Date
        public let workouts: Int
    }

    /// "From 70 to 78 kg at 0.35 kg/week ≈ 23 weeks ≈ by <date>, ≈ 69 workouts at 3/week".
    public static func forecast(
        currentKg: Double, targetKg: Double, kgPerWeek: Double, sessionsPerWeek: Int,
        from start: Date = .now, calendar: Calendar = .current
    ) -> Forecast? {
        let delta = targetKg - currentKg
        guard kgPerWeek != 0, delta != 0, delta.sign == kgPerWeek.sign else { return nil }
        let weeks = delta / kgPerWeek
        let days = Int((weeks * 7).rounded())
        guard let date = calendar.date(byAdding: .day, value: days, to: start) else { return nil }
        let workouts = Int((weeks * Double(sessionsPerWeek)).rounded())
        return Forecast(weeks: weeks, targetDate: date, workouts: workouts)
    }

    /// Straight projected line (one point per week) for the dashed forecast on the chart.
    public static func projection(from start: WeightSample, kgPerWeek: Double, targetKg: Double, calendar: Calendar = .current) -> [WeightSample] {
        guard kgPerWeek != 0 else { return [start] }
        var points = [start]
        var weight = start.weightKg
        var week = 0
        let maxWeeks = 156
        while week < maxWeeks {
            week += 1
            weight += kgPerWeek
            let reached = kgPerWeek > 0 ? weight >= targetKg : weight <= targetKg
            guard let date = calendar.date(byAdding: .day, value: week * 7, to: start.date) else { break }
            points.append(WeightSample(date: date, weightKg: reached ? targetKg : weight))
            if reached { break }
        }
        return points
    }
}
