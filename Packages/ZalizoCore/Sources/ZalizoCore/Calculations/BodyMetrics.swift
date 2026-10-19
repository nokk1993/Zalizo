import Foundation

/// Body composition and energy-expenditure formulas.
public enum BodyMetrics {
    /// Body-mass index, kg/m². Not meaningful for muscular people: it cannot tell muscle from fat.
    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let meters = heightCm / 100
        return weightKg / (meters * meters)
    }

    /// Basal metabolic rate, kcal/day — Mifflin–St Jeor (1990), the most accurate predictive
    /// equation for healthy adults (ADA Evidence Analysis Library, 2005).
    /// Men: 10·kg + 6.25·cm − 5·age + 5; women: same − 161.
    public static func bmr(sex: Sex, weightKg: Double, heightCm: Double, ageYears: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// Physical-activity multiplier. Values already include ~3 resistance-training sessions per week
    /// (classic Harris–Benedict/McArdle factors: lightly 1.375, moderately 1.55, very active 1.725).
    public static func activityFactor(_ level: ActivityLevel) -> Double {
        switch level {
        case .sedentary: 1.375
        case .moderate: 1.55
        case .physical: 1.725
        }
    }

    /// Total daily energy expenditure, kcal/day.
    public static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activityFactor(activity)
    }

    /// Full years between birth date and `now`.
    public static func age(birthDate: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0)
    }

    public struct FFMIResult: Equatable, Sendable {
        public let leanMassKg: Double
        public let ffmi: Double
        /// Adjusted to 1.8 m height (Kouri et al., 1995): FFMI + 6.1·(1.8 − height m).
        public let normalizedFFMI: Double
    }

    /// Fat-free mass index — informational only, requires a body-fat estimate.
    public static func ffmi(weightKg: Double, heightCm: Double, bodyFatPercent: Double) -> FFMIResult? {
        guard heightCm > 0, (0..<100).contains(bodyFatPercent) else { return nil }
        let meters = heightCm / 100
        let lean = weightKg * (1 - bodyFatPercent / 100)
        let index = lean / (meters * meters)
        return FFMIResult(leanMassKg: lean, ffmi: index, normalizedFFMI: index + 6.1 * (1.8 - meters))
    }
}
