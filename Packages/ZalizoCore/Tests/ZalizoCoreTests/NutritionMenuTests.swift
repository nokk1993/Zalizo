import Foundation
import Testing
@testable import ZalizoCore

extension SeedFiles {
    static func foods() throws -> FoodFile {
        try FoodFile.decode(Data(contentsOf: url("Zalizo/Resources/Seed/foods.json")))
    }

    static func menus() throws -> MenuFile {
        try MenuFile.decode(Data(contentsOf: url("Zalizo/Resources/Seed/menus.json")))
    }
}

@Suite("Menus")
struct MenuBuilderTests {
    @Test func seedIsComplete() throws {
        let foods = try SeedFiles.foods()
        #expect((90...120).contains(foods.foods.count))
        let ids = Set(foods.foods.map(\.id))
        for menu in try SeedFiles.menus().menus {
            #expect(menu.meals.count == 6)
            for item in menu.meals.flatMap(\.items) {
                #expect(ids.contains(item.food), "\(menu.id): \(item.food)")
            }
        }
        for (_, list) in foods.substitutes {
            #expect(list.allSatisfy(ids.contains))
        }
        #expect(try SeedFiles.menus().menus.count >= 5)
    }

    @Test("Scales to calorie levels", arguments: [2500, 2800, 3100, 3400, 3700])
    func scaling(target: Int) throws {
        let foods = try SeedFiles.foods()
        for template in try SeedFiles.menus().menus {
            let menu = MenuBuilder.build(template, foods: foods, targetKcal: target, mealsPerDay: 5, exclusions: [], budget: .medium)
            let kcal = menu.totals.kcal
            #expect(abs(kcal - Double(target)) / Double(target) < 0.05, "\(template.id): \(kcal)")
            #expect(menu.meals.count == 5)
            #expect(menu.totals.protein * 4 / kcal > 0.2, "\(template.id) protein share")
        }
    }

    @Test func mealsPerDay() throws {
        let foods = try SeedFiles.foods()
        let template = try #require(try SeedFiles.menus().menus.first)
        for count in 3...6 {
            let menu = MenuBuilder.build(template, foods: foods, targetKcal: 2800, mealsPerDay: count, exclusions: [], budget: .medium)
            #expect(menu.meals.count == count)
        }
        let three = MenuBuilder.build(template, foods: foods, targetKcal: 2800, mealsPerDay: 3, exclusions: [], budget: .medium)
        #expect(three.meals.map(\.slot) == [.breakfast, .lunch, .dinner])
    }

    @Test func exclusionsAreRespected() throws {
        let foods = try SeedFiles.foods()
        let exclusions: Set<DietExclusion> = [.dairy, .nuts, .gluten, .fish]
        for template in try SeedFiles.menus().menus {
            let menu = MenuBuilder.build(template, foods: foods, targetKcal: 3000, mealsPerDay: 6, exclusions: exclusions, budget: .medium)
            for portion in menu.meals.flatMap(\.portions) {
                #expect(portion.food.isAllowed(exclusions: exclusions, budget: .medium), "\(template.id): \(portion.food.id)")
            }
            #expect(abs(menu.totals.kcal - 3000) < 150)
        }
    }

    @Test func economyBudgetAvoidsPremium() throws {
        let foods = try SeedFiles.foods()
        let template = try #require(try SeedFiles.menus().menus.first { $0.id == "pasta-turkey" })
        let menu = MenuBuilder.build(template, foods: foods, targetKcal: 2800, mealsPerDay: 6, exclusions: [], budget: .economy)
        #expect(menu.meals.flatMap(\.portions).allSatisfy { !$0.food.premium })
        #expect(menu.meals.flatMap(\.portions).contains { $0.replaced != nil })
    }

    @Test func eggsAreWholeUnits() throws {
        let foods = try SeedFiles.foods()
        let template = try #require(try SeedFiles.menus().menus.first { $0.id == "classic-oats" })
        let menu = MenuBuilder.build(template, foods: foods, targetKcal: 3700, mealsPerDay: 6, exclusions: [], budget: .medium)
        let eggs = try #require(menu.meals.flatMap(\.portions).first { $0.food.id == "egg" })
        #expect(eggs.grams.truncatingRemainder(dividingBy: 55) == 0)
    }

    @Test func substitutionKeepsProtein() {
        let chicken = Food(id: "c", name: "Курка", kcal: 113, protein: 23.6, fat: 1.9, carbs: 0, role: "protein")
        let cottage = Food(id: "s", name: "Сир", kcal: 121, protein: 17.2, fat: 5, carbs: 1.8, role: "dairy-protein", tags: ["dairy"])
        #expect(approx(MenuBuilder.equivalentGrams(200, from: cottage, to: chicken), 145.8, 0.1))
        let oil = Food(id: "o", name: "Олія", kcal: 899, protein: 0, fat: 99.9, carbs: 0, role: "oil")
        let butter = Food(id: "b", name: "Масло", kcal: 748, protein: 0.5, fat: 82.5, carbs: 0.8, role: "fat")
        #expect(approx(MenuBuilder.equivalentGrams(10, from: butter, to: oil), 8.32, 0.01))
    }

    @Test func shoppingList() throws {
        let foods = try SeedFiles.foods()
        let templates = try SeedFiles.menus().menus
        let week = MenuBuilder.week(templates: templates, start: 0, foods: foods, targetKcal: 2800, mealsPerDay: 5, exclusions: [], budget: .medium)
        #expect(week.count == 7)
        let list = MenuBuilder.shoppingList(week)
        #expect(!list.isEmpty)
        #expect(list.allSatisfy { $0.grams.truncatingRemainder(dividingBy: 50) == 0 })
        let eggs = try #require(list.first { $0.food.id == "egg" })
        #expect((eggs.units ?? 0) > 0)
        #expect(MenuBuilder.week(templates: [], start: 0, foods: foods, targetKcal: 2800, mealsPerDay: 5, exclusions: [], budget: .medium).isEmpty)
    }

    @Test func foodMacros() {
        let oats = Food(id: "oats", name: "Вівсянка", kcal: 366, protein: 12.3, fat: 6.1, carbs: 59.5, fiber: 10, role: "carb")
        let macros = oats.macros(grams: 80)
        #expect(approx(macros.kcal, 292.8))
        #expect(approx(macros.protein, 9.84))
        #expect(approx(macros.fiber, 8))
    }
}
