import Foundation

/// Sensible defaults used when the user skips an onboarding question.
/// None of these values describe a real person.
public enum Defaults {
    public static let sex: Sex = .male // DEFAULT
    public static let ageYears = 25 // DEFAULT
    public static let heightCm = 178.0 // DEFAULT
    public static let weightKg = 72.0 // DEFAULT
    public static let experience: ExperienceLevel = .beginner // DEFAULT
    public static let goal: TrainingGoal = .muscleGain // DEFAULT
    public static let activity: ActivityLevel = .sedentary // DEFAULT
    public static let trainingDays: [Weekday] = [.monday, .wednesday, .friday] // DEFAULT
    public static let sessionMinutes = 60 // DEFAULT
    public static let mealsPerDay = 4 // DEFAULT
    public static let budget: FoodBudget = .medium // DEFAULT
    public static let equipment: [Equipment] = [
        .barbell, .dumbbells, .cables, .machines, .pullUpBar, .dipBars, .adjustableBench, .ezBar, .bodyweight
    ] // DEFAULT: a typical commercial gym
    public static let dumbbellMaxKg = 40.0 // DEFAULT

    public static let proteinPerKg = 1.8 // DEFAULT, range 1.6–2.2
    public static let fatPerKg = 0.9 // DEFAULT, range 0.8–1.0

    public static let barbellStepKg = 2.5 // DEFAULT
    public static let dumbbellStepKg = 2.0 // DEFAULT
    public static let machineStepKg = 5.0 // DEFAULT
    public static let barWeightKg = 20.0 // DEFAULT
    /// Plates available per side, kg (one pair of each assumed unlimited).
    public static let plates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25] // DEFAULT
    public static let restSeconds = 120 // DEFAULT
}
