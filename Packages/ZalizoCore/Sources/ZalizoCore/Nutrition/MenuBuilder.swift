import Foundation

/// Food composition per 100 g (`Resources/Seed/foods.json`).
public struct Food: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kcal: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double
    public var fiber: Double
    /// Substitution group: carb, protein, milk, nut, fruit…
    public var role: String
    /// Raw values of `DietExclusion` this food conflicts with.
    public var tags: [String]
    /// Not part of an economy budget.
    public var premium: Bool
    /// Natural unit (egg 55 g, banana 120 g) — grams are rounded to whole units.
    public var unitGrams: Double?

    public init(
        id: String, name: String, kcal: Double, protein: Double, fat: Double, carbs: Double, fiber: Double = 0,
        role: String, tags: [String] = [], premium: Bool = false, unitGrams: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.fiber = fiber
        self.role = role
        self.tags = tags
        self.premium = premium
        self.unitGrams = unitGrams
    }

    public func macros(grams: Double) -> MacroTotals {
        let factor = grams / 100
        return MacroTotals(kcal: kcal * factor, protein: protein * factor, fat: fat * factor, carbs: carbs * factor, fiber: fiber * factor)
    }

    public func isAllowed(exclusions: Set<DietExclusion>, budget: FoodBudget) -> Bool {
        if budget == .economy && premium { return false }
        return !tags.contains { tag in exclusions.contains { $0.rawValue == tag } }
    }
}

public struct MacroTotals: Equatable, Sendable {
    public var kcal: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double
    public var fiber: Double

    public init(kcal: Double = 0, protein: Double = 0, fat: Double = 0, carbs: Double = 0, fiber: Double = 0) {
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.fiber = fiber
    }

    public static func + (lhs: MacroTotals, rhs: MacroTotals) -> MacroTotals {
        MacroTotals(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein, fat: lhs.fat + rhs.fat,
                    carbs: lhs.carbs + rhs.carbs, fiber: lhs.fiber + rhs.fiber)
    }
}

public struct FoodFile: Codable, Equatable, Sendable {
    public var version: Int
    public var foods: [Food]
    /// role → preferred replacement order
    public var substitutes: [String: [String]]

    public init(version: Int, foods: [Food], substitutes: [String: [String]]) {
        self.version = version
        self.foods = foods
        self.substitutes = substitutes
    }

    public static func decode(_ data: Data) throws -> FoodFile {
        try JSONDecoder().decode(FoodFile.self, from: data)
    }

    public var byID: [String: Food] {
        Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

public enum MealSlot: String, Codable, CaseIterable, Sendable {
    case breakfast, snack1, lunch, snack2, dinner, beforeBed
}

public struct MenuTemplate: Codable, Equatable, Sendable, Identifiable {
    public struct Item: Codable, Equatable, Sendable {
        public var food: String
        public var grams: Double

        public init(food: String, grams: Double) {
            self.food = food
            self.grams = grams
        }
    }

    public struct Meal: Codable, Equatable, Sendable {
        public var slot: MealSlot
        public var items: [Item]

        public init(slot: MealSlot, items: [Item]) {
            self.slot = slot
            self.items = items
        }
    }

    public var id: String
    public var name: String
    public var budget: FoodBudget
    public var meals: [Meal]

    public init(id: String, name: String, budget: FoodBudget, meals: [Meal]) {
        self.id = id
        self.name = name
        self.budget = budget
        self.meals = meals
    }
}

public struct MenuFile: Codable, Equatable, Sendable {
    public var version: Int
    public var menus: [MenuTemplate]

    public static func decode(_ data: Data) throws -> MenuFile {
        try JSONDecoder().decode(MenuFile.self, from: data)
    }
}

/// A concrete day of eating for the user's calorie target.
public struct PlannedMenu: Equatable, Sendable {
    public struct Portion: Equatable, Sendable {
        public let food: Food
        public let grams: Double
        public let macros: MacroTotals
        /// Name of the original food when it was replaced (allergy/diet/budget).
        public let replaced: String?
    }

    public struct Meal: Equatable, Sendable {
        public let slot: MealSlot
        public let portions: [Portion]

        public var totals: MacroTotals { portions.reduce(MacroTotals()) { $0 + $1.macros } }
    }

    public let templateID: String
    public let name: String
    public let meals: [Meal]

    public var totals: MacroTotals { meals.reduce(MacroTotals()) { $0 + $1.totals } }
}

public enum MenuBuilder {
    static let proteinRoles: Set<String> = ["protein", "egg", "dairy-protein", "plant-protein", "cheese", "legume"]

    /// Templates in display order: ones matching the budget first.
    public static func orderedTemplates(_ templates: [MenuTemplate], budget: FoodBudget) -> [MenuTemplate] {
        templates.filter { $0.budget == budget } + templates.filter { $0.budget != budget }
    }

    public static func build(
        _ template: MenuTemplate, foods: FoodFile, targetKcal: Int, mealsPerDay: Int,
        exclusions: Set<DietExclusion>, budget: FoodBudget
    ) -> PlannedMenu {
        let catalog = foods.byID
        // 1. Substitute foods that are not allowed.
        let substituted: [(slot: MealSlot, items: [(food: Food, grams: Double, replaced: String?)])] = template.meals.map { meal in
            (meal.slot, meal.items.compactMap { item in
                guard let original = catalog[item.food] else { return nil }
                if original.isAllowed(exclusions: exclusions, budget: budget) {
                    return (original, item.grams, nil)
                }
                guard let replacement = substitute(for: original, foods: foods, exclusions: exclusions, budget: budget) else { return nil }
                return (replacement, equivalentGrams(item.grams, from: original, to: replacement), original.name)
            })
        }
        // 2. Merge meal slots down to the requested number of meals.
        let merged = merge(substituted, mealsPerDay: mealsPerDay)
        // 3. Scale to the calorie target.
        let baseKcal = merged.flatMap(\.items).reduce(0) { $0 + $1.food.kcal * $1.grams / 100 }
        let factor = baseKcal > 0 ? Double(targetKcal) / baseKcal : 1
        let meals = merged.map { meal in
            PlannedMenu.Meal(slot: meal.slot, portions: meal.items.map { item in
                let grams = roundGrams(item.grams * factor, food: item.food)
                return PlannedMenu.Portion(food: item.food, grams: grams, macros: item.food.macros(grams: grams), replaced: item.replaced)
            })
        }
        return PlannedMenu(templateID: template.id, name: template.name, meals: meals)
    }

    static func substitute(for food: Food, foods: FoodFile, exclusions: Set<DietExclusion>, budget: FoodBudget) -> Food? {
        let catalog = foods.byID
        var candidates = foods.substitutes[food.role] ?? []
        if proteinRoles.contains(food.role) {
            candidates += foods.substitutes["protein"] ?? []
        }
        return candidates
            .compactMap { catalog[$0] }
            .first { $0.id != food.id && $0.isAllowed(exclusions: exclusions, budget: budget) }
    }

    /// Same protein for protein foods (capped), same calories otherwise.
    static func equivalentGrams(_ grams: Double, from original: Food, to replacement: Food) -> Double {
        if proteinRoles.contains(original.role), original.protein > 0, replacement.protein > 0 {
            return min(grams * original.protein / replacement.protein, grams * 3)
        }
        guard replacement.kcal > 0 else { return grams }
        return min(grams * original.kcal / replacement.kcal, grams * 3)
    }

    /// 6 meals → as planned; 5 → before-bed joins the afternoon snack; 4 → morning snack joins breakfast;
    /// 3 → afternoon snack joins lunch.
    static func merge<T>(_ meals: [(slot: MealSlot, items: [T])], mealsPerDay: Int) -> [(slot: MealSlot, items: [T])] {
        var result = meals
        func fold(_ from: MealSlot, into target: MealSlot) {
            guard let source = result.firstIndex(where: { $0.slot == from }),
                  let destination = result.firstIndex(where: { $0.slot == target }) else { return }
            result[destination].items += result[source].items
            result.remove(at: source)
        }
        let count = min(max(mealsPerDay, 3), 6)
        if count <= 5 { fold(.beforeBed, into: .snack2) }
        if count <= 4 { fold(.snack1, into: .breakfast) }
        if count <= 3 { fold(.snack2, into: .lunch) }
        return result.filter { !$0.items.isEmpty }
    }

    static func roundGrams(_ grams: Double, food: Food) -> Double {
        if let unit = food.unitGrams, unit > 0 {
            return max(1, (grams / unit).rounded()) * unit
        }
        let step: Double = grams < 50 ? 5 : 10
        return max(5, (grams / step).rounded() * step)
    }

    // MARK: Shopping list

    public struct ShoppingItem: Equatable, Sendable {
        public let food: Food
        public let grams: Double
        /// Whole units for eggs/fruit, nil otherwise.
        public let units: Int?
    }

    /// Weekly list from 7 daily menus. Grams are rounded up to 50 g.
    public static func shoppingList(_ days: [PlannedMenu]) -> [ShoppingItem] {
        var totals: [String: (food: Food, grams: Double)] = [:]
        for day in days {
            for portion in day.meals.flatMap(\.portions) {
                totals[portion.food.id, default: (portion.food, 0)].grams += portion.grams
            }
        }
        return totals.values
            .map { entry in
                let units = entry.food.unitGrams.map { Int((entry.grams / $0).rounded(.up)) }
                return ShoppingItem(food: entry.food, grams: (entry.grams / 50).rounded(.up) * 50, units: units)
            }
            .sorted { ($0.food.role, $0.food.name) < ($1.food.role, $1.food.name) }
    }

    /// One menu per day of the week, rotating through templates starting from `start`.
    public static func week(
        templates: [MenuTemplate], start: Int, foods: FoodFile, targetKcal: Int, mealsPerDay: Int,
        exclusions: Set<DietExclusion>, budget: FoodBudget
    ) -> [PlannedMenu] {
        guard !templates.isEmpty else { return [] }
        return (0..<7).map { day in
            build(templates[(start + day) % templates.count], foods: foods, targetKcal: targetKcal,
                  mealsPerDay: mealsPerDay, exclusions: exclusions, budget: budget)
        }
    }
}
