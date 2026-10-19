import Foundation

/// Daily calorie and macro targets.
///
/// Sources: ISSN position stand on protein and exercise (Jäger et al., 2017: 1.4–2.0 g/kg, up to 2.2);
/// Iraki et al., 2019 (nutrition recommendations for bodybuilders in the off-season: surplus 10–20 %
/// for novices, smaller for advanced; fat 0.5–1.5 g/kg, ≥20 % kcal); EFSA dietary reference values
/// (water, fibre ≈ 14 g / 1000 kcal per US DGA).
public enum NutritionCalculator {
    public struct Input: Equatable, Sendable {
        public var sex: Sex
        public var ageYears: Int
        public var heightCm: Double
        public var weightKg: Double
        public var activity: ActivityLevel
        public var experience: ExperienceLevel
        public var goal: TrainingGoal
        public var proteinPerKg: Double
        public var fatPerKg: Double
        /// nil → default for goal/experience.
        public var surplusPercentOverride: Double?
        /// Confirmed adaptive corrections (sum), kcal.
        public var adjustmentKcal: Int
        /// Extra carbohydrate kcal on training days (0…200).
        public var trainingDayCarbBoostKcal: Int

        public init(
            sex: Sex, ageYears: Int, heightCm: Double, weightKg: Double,
            activity: ActivityLevel, experience: ExperienceLevel, goal: TrainingGoal,
            proteinPerKg: Double = Defaults.proteinPerKg, fatPerKg: Double = Defaults.fatPerKg,
            surplusPercentOverride: Double? = nil, adjustmentKcal: Int = 0, trainingDayCarbBoostKcal: Int = 0
        ) {
            self.sex = sex
            self.ageYears = ageYears
            self.heightCm = heightCm
            self.weightKg = weightKg
            self.activity = activity
            self.experience = experience
            self.goal = goal
            self.proteinPerKg = proteinPerKg
            self.fatPerKg = fatPerKg
            self.surplusPercentOverride = surplusPercentOverride
            self.adjustmentKcal = adjustmentKcal
            self.trainingDayCarbBoostKcal = trainingDayCarbBoostKcal
        }
    }

    public struct Macros: Equatable, Sendable {
        public let kcal: Int
        public let proteinG: Int
        public let fatG: Int
        public let carbsG: Int

        public var proteinPercent: Double { percent(Double(proteinG) * 4) }
        public var fatPercent: Double { percent(Double(fatG) * 9) }
        public var carbsPercent: Double { percent(Double(carbsG) * 4) }

        private func percent(_ part: Double) -> Double {
            kcal > 0 ? part / Double(kcal) * 100 : 0
        }
    }

    public struct Targets: Equatable, Sendable {
        public let bmr: Double
        public let tdee: Double
        /// Applied surplus (+) or deficit (−), % of TDEE.
        public let surplusPercent: Double
        public let restDay: Macros
        public let trainingDay: Macros
        public let waterRestDayMl: Int
        public let waterTrainingDayMl: Int
        public let fiberG: Int
    }

    public static let kcalPerGramProtein = 4.0
    public static let kcalPerGramCarbs = 4.0
    public static let kcalPerGramFat = 9.0
    /// Fat must provide at least this share of calories (hormonal health).
    public static let minFatShare = 0.20

    /// Default energy surplus for the goal, % of TDEE.
    /// Muscle gain: novice +12 % (range 10–15), trained +8 % (range 5–10).
    public static func defaultSurplusPercent(goal: TrainingGoal, experience: ExperienceLevel) -> Double {
        switch goal {
        case .muscleGain: experience.isNovice ? 12 : 8
        case .strength: 5
        case .recomposition: -10
        case .maintenance: 0
        }
    }

    public static func targets(for input: Input) -> Targets {
        let bmr = BodyMetrics.bmr(sex: input.sex, weightKg: input.weightKg, heightCm: input.heightCm, ageYears: input.ageYears)
        let tdee = BodyMetrics.tdee(bmr: bmr, activity: input.activity)
        let surplus = input.surplusPercentOverride ?? defaultSurplusPercent(goal: input.goal, experience: input.experience)
        let baseKcal = roundTo10(tdee * (1 + surplus / 100)) + input.adjustmentKcal

        let restDay = macros(kcal: baseKcal, weightKg: input.weightKg, proteinPerKg: input.proteinPerKg, fatPerKg: input.fatPerKg)
        let trainingKcal = baseKcal + input.trainingDayCarbBoostKcal
        let trainingDay = macros(kcal: trainingKcal, weightKg: input.weightKg, proteinPerKg: input.proteinPerKg, fatPerKg: input.fatPerKg)

        let water = waterMl(weightKg: input.weightKg, trainingDay: false)
        return Targets(
            bmr: bmr,
            tdee: tdee,
            surplusPercent: surplus,
            restDay: restDay,
            trainingDay: trainingDay,
            waterRestDayMl: water,
            waterTrainingDayMl: waterMl(weightKg: input.weightKg, trainingDay: true),
            fiberG: fiberG(kcal: baseKcal)
        )
    }

    /// Protein and fat are set per kg of body weight, carbohydrates fill the remaining calories.
    public static func macros(kcal: Int, weightKg: Double, proteinPerKg: Double, fatPerKg: Double) -> Macros {
        let kcalDouble = Double(kcal)
        let protein = (weightKg * proteinPerKg).rounded()
        let fatFromWeight = weightKg * fatPerKg
        let fatFloor = kcalDouble * minFatShare / kcalPerGramFat
        let fat = max(fatFromWeight, fatFloor).rounded()
        let remaining = kcalDouble - protein * kcalPerGramProtein - fat * kcalPerGramFat
        let carbs = max(0, remaining / kcalPerGramCarbs).rounded(.down)
        return Macros(kcal: kcal, proteinG: Int(protein), fatG: Int(fat), carbsG: Int(carbs))
    }

    /// ~35 ml per kg of body weight, +500 ml on a training day; rounded to 50 ml.
    public static func waterMl(weightKg: Double, trainingDay: Bool) -> Int {
        let base = weightKg * 35 + (trainingDay ? 500 : 0)
        return Int((base / 50).rounded()) * 50
    }

    /// ~14 g of fibre per 1000 kcal.
    public static func fiberG(kcal: Int) -> Int {
        Int((Double(kcal) * 14 / 1000).rounded())
    }

    static func roundTo10(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }
}
