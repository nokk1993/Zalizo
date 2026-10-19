import Foundation
import SwiftData
import ZalizoCore

/// Bundled food reference and menus, today's diary, water and adaptive calorie corrections.
@MainActor
enum NutritionStore {
    private static var cachedFoods: FoodFile?
    private static var cachedMenus: MenuFile?

    static func foods(bundle: Bundle = .main) -> FoodFile {
        if let cachedFoods { return cachedFoods }
        let file = bundle.url(forResource: "foods", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? FoodFile.decode($0) } ?? FoodFile(version: 0, foods: [], substitutes: [:])
        cachedFoods = file
        return file
    }

    static func menus(bundle: Bundle = .main) -> [MenuTemplate] {
        if let cachedMenus { return cachedMenus.menus }
        let file = bundle.url(forResource: "menus", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? MenuFile.decode($0) }
        cachedMenus = file
        return file?.menus ?? []
    }

    // MARK: Diary

    static func log(for date: Date = .now, in context: ModelContext, create: Bool = true) -> NutritionLog? {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date
        let descriptor = FetchDescriptor<NutritionLog>(predicate: #Predicate { $0.day >= start && $0.day < end })
        if let existing = try? context.fetch(descriptor).first { return existing }
        guard create else { return nil }
        let log = NutritionLog(day: start)
        context.insert(log)
        return log
    }

    static func addWater(_ ml: Int, on date: Date = .now, in context: ModelContext) {
        guard let log = log(for: date, in: context) else { return }
        log.waterMl = max(0, log.waterMl + ml)
        try? context.save()
    }

    static func add(_ entry: FoodEntry, on date: Date = .now, in context: ModelContext) {
        guard let log = log(for: date, in: context) else { return }
        log.entries.append(entry)
        try? context.save()
    }

    static func entry(for food: Food, grams: Double) -> FoodEntry {
        let macros = food.macros(grams: grams)
        return FoodEntry(name: food.name, kcal: macros.kcal.rounded(), protein: macros.protein, fat: macros.fat, carbs: macros.carbs, grams: grams)
    }

    /// Is `date` one of the user's training weekdays (training-day targets apply)?
    static func isTrainingDay(_ date: Date = .now, profile: ProfileSnapshot) -> Bool {
        profile.trainingDays.contains(Weekday.from(date: date))
    }

    // MARK: Adaptive correction

    static func adaptiveEvaluation(in context: ModelContext, now: Date = .now) -> AdaptiveCalories.Evaluation {
        let weights = (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
        var adjustments = FetchDescriptor<CalorieAdjustment>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        adjustments.fetchLimit = 1
        let lastCheck = (try? context.fetch(adjustments).first)?.date
            ?? ProfileStore.profile(in: context)?.createdAt
        let snapshot = ProfileStore.snapshot(in: context)
        return AdaptiveCalories.evaluate(
            samples: StatsStore.weightSamples(weights), experience: snapshot.experience, goal: snapshot.goal,
            lastCheck: lastCheck, now: now
        )
    }

    static func resolve(_ proposal: AdaptiveCalories.Proposal, accepted: Bool, in context: ModelContext) {
        context.insert(CalorieAdjustment(date: .now, deltaKcal: proposal.deltaKcal, weeklyGainPercent: proposal.weeklyGainPercent, accepted: accepted))
        if accepted, let profile = ProfileStore.profile(in: context) {
            profile.calorieAdjustmentKcal += proposal.deltaKcal
        }
        try? context.save()
    }
}

extension MealSlot {
    var title: LocalizedStringResource {
        switch self {
        case .breakfast: "Сніданок"
        case .snack1: "Перекус"
        case .lunch: "Обід"
        case .snack2: "Полуденок"
        case .dinner: "Вечеря"
        case .beforeBed: "Перед сном"
        }
    }
}
