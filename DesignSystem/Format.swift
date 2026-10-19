import Foundation
import ShahCore

/// Localized display strings. Keys live in Resources/Localizable.xcstrings
/// (Ukrainian source, English translation, plural rules for both).
enum Format {
    private static let nbsp = "\u{00A0}"
    private static let minus = "\u{2212}"

    /// «7,4»
    static func distance(_ meters: Double, _ unit: DistanceUnit, digits: Int = 1) -> String {
        DistanceFormat.number(meters: meters, unit: unit, fractionDigits: digits)
    }

    /// «7,4 км»
    static func distanceWithUnit(_ meters: Double, _ unit: DistanceUnit, digits: Int = 1) -> String {
        distance(meters, unit, digits: digits) + nbsp + String(localized: unit.shortLabel)
    }

    /// «+1,2 км», «−0,8 км»
    static func signed(_ comparison: Comparison, _ unit: DistanceUnit) -> String? {
        switch comparison {
        case .more(let meters): "+" + distanceWithUnit(meters, unit)
        case .less(let meters): minus + distanceWithUnit(meters, unit)
        case .same: nil
        }
    }

    /// Goal with as few decimals as needed: «5 км», «5,5 км».
    static func goal(_ meters: Double, _ unit: DistanceUnit) -> String {
        goalNumber(meters, unit) + nbsp + String(localized: unit.shortLabel)
    }

    static func goalNumber(_ meters: Double, _ unit: DistanceUnit) -> String {
        let value = (unit.value(fromMeters: meters) / AppSettings.goalStep).rounded() * AppSettings.goalStep
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// «10 482 кроки», «1 крок», «5 кроків»
    static func steps(_ steps: Int) -> String {
        DistanceFormat.steps(steps) + nbsp + String(localized: "steps.word", defaultValue: "\(steps) кроків",
                                                     comment: "Only the word for steps, in the plural form for the number. The number is shown separately.")
    }

    /// «74% · ціль 10 км»
    static func progressLine(_ summary: TodaySummary, _ unit: DistanceUnit) -> String {
        let percent = DistanceFormat.percent(summary.progress)
        let goalText = goal(summary.goalMeters, unit)
        return String(localized: "\(percent)% · ціль \(goalText)")
    }

    /// VoiceOver: «Сьогодні пройдено 7,4 кілометра, 74 відсотки цілі».
    static func todayAccessibility(_ summary: TodaySummary, _ unit: DistanceUnit) -> String {
        let spoken = distance(summary.meters, unit) + " " + String(localized: unit.spokenName)
        let percent = DistanceFormat.percent(summary.progress)
        return String(localized: "today.accessibility", defaultValue: "Сьогодні пройдено \(spoken), \(percent) відсотків цілі")
    }

    /// Yesterday card: value and caption.
    static func yesterday(_ summary: TodaySummary, _ unit: DistanceUnit) -> (title: String, value: String, caption: String, isMore: Bool) {
        guard let yesterday = summary.yesterdayMeters else {
            return (String(localized: "Учора"), "—", String(localized: "ще немає даних"), false)
        }
        let title = String(localized: "Учора · \(distanceWithUnit(yesterday, unit))")
        let comparison = Comparison(summary.meters, versus: yesterday, unit: unit)
        switch comparison {
        case .more: return (title, signed(comparison, unit)!, String(localized: "більше, ніж учора"), true)
        case .less: return (title, signed(comparison, unit)!, String(localized: "менше, ніж учора"), false)
        case .same: return (title, String(localized: "Так само"), String(localized: "як і вчора"), false)
        }
    }

    /// "Usual" card: compared with the average of the previous 7 days.
    static func usual(_ summary: TodaySummary, _ unit: DistanceUnit) -> (title: String, value: String, caption: String, isMore: Bool) {
        guard let average = summary.weekAverageMeters else {
            return (String(localized: "Зазвичай"), "—", String(localized: "ще немає даних"), false)
        }
        let title = String(localized: "Зазвичай · \(distanceWithUnit(average, unit))")
        let comparison = Comparison(summary.meters, versus: average, unit: unit)
        switch comparison {
        case .more: return (title, signed(comparison, unit)!, String(localized: "більше, ніж зазвичай"), true)
        case .less: return (title, signed(comparison, unit)!, String(localized: "менше, ніж зазвичай"), false)
        case .same: return (title, String(localized: "Так само"), String(localized: "як зазвичай"), false)
        }
    }

    static func streakCurrent(_ days: Int) -> String {
        String(localized: "streak.current", defaultValue: "\(days) днів поспіль")
    }

    static func streakBest(_ days: Int) -> String {
        String(localized: "streak.best", defaultValue: "рекорд \(days) днів")
    }

    /// Onboarding: «≈ 6 600 кроків · 1 год ходьби» for a goal.
    static func goalEstimate(_ meters: Double) -> String {
        let steps = Int((meters / 0.762 / 100).rounded()) * 100
        let minutes = Int((meters / 5_000 * 60 / 5).rounded()) * 5 // 5 km/h, rounded to 5 min
        let time = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return String(localized: "≈ \(Format.steps(steps)) · \(time) ходьби")
    }

    static func dayKeyDate(_ day: DayKey) -> Date {
        day.startDate(in: .current)
    }
}

extension DistanceUnit {
    /// Unit name for VoiceOver after a number with one decimal.
    var spokenName: LocalizedStringResource {
        switch self {
        case .kilometers: LocalizedStringResource("unit.km.spoken", defaultValue: "кілометра")
        case .miles: LocalizedStringResource("unit.mi.spoken", defaultValue: "милі")
        }
    }
}
