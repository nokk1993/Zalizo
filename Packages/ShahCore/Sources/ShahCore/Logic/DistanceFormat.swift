import Foundation

/// Locale-aware number formatting. Unit labels ("км", "mi") come from the
/// app's String Catalog, because the UI lays the number and the unit out
/// separately (big number, small unit).
public enum DistanceFormat {
    /// "7,4" in Ukrainian, "7.4" in English.
    public static func number(meters: Double, unit: DistanceUnit, fractionDigits: Int = 1, locale: Locale = .current) -> String {
        let value = unit.value(fromMeters: meters)
        return value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// Plain value in the unit, rounded the same way the UI shows it.
    public static func rounded(meters: Double, unit: DistanceUnit, fractionDigits: Int = 1) -> Double {
        let scale = pow(10, Double(fractionDigits))
        return (unit.value(fromMeters: meters) * scale).rounded() / scale
    }

    /// "10 482" with the locale's grouping separator.
    public static func steps(_ steps: Int, locale: Locale = .current) -> String {
        steps.formatted(.number.locale(locale))
    }

    /// Whole percent, e.g. 74.
    public static func percent(_ progress: Double) -> Int {
        Int((progress * 100).rounded(.down))
    }
}

public enum DayClock {
    /// The moment the next day begins in `timeZone` — when "today" must reset.
    public static func nextDayStart(after date: Date, in timeZone: TimeZone) -> Date {
        DayKey(date, in: timeZone).advanced(by: 1).startDate(in: timeZone)
    }
}
