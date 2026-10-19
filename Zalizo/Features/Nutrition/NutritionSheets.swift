import SwiftData
import SwiftUI
import ZalizoCore

/// Add food: quick (kcal + protein) or from the built-in reference with grams.
struct AddFoodSheet: View {
    enum Mode: String, CaseIterable {
        case reference, quick

        var title: LocalizedStringResource {
            switch self {
            case .reference: "З довідника"
            case .quick: "Швидко"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .reference
    @State private var search = ""
    @State private var selected: Food?
    @State private var grams: Double = 100
    @State private var quickName = ""
    @State private var quickKcal: Double?
    @State private var quickProtein: Double?

    private var foods: [Food] {
        NutritionStore.foods().foods
            .filter { SearchText.matches(query: search, fields: [$0.name]) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Спосіб", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch mode {
                case .reference:
                    if let selected {
                        Section {
                            Text(selected.name).font(.headline)
                            Stepper(value: $grams, in: 5...2000, step: grams < 50 ? 5 : 10) {
                                Text("\(Int(grams)) г").monospacedDigit()
                            }
                            let macros = selected.macros(grams: grams)
                            Text("\(Int(macros.kcal)) ккал · Б \(macros.protein.kgText) · Ж \(macros.fat.kgText) · В \(macros.carbs.kgText)")
                                .font(.subheadline.monospacedDigit())
                            Button("Обрати інший продукт") { self.selected = nil }
                        }
                    } else {
                        Section {
                            TextField("Пошук продукту", text: $search)
                            ForEach(foods) { food in
                                Button {
                                    selected = food
                                    grams = food.unitGrams ?? 100
                                } label: {
                                    HStack {
                                        Text(food.name).foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(Int(food.kcal)) ккал/100 г").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } footer: {
                            Text("Значення на 100 г: сирі продукти, сухі крупи.")
                        }
                    }
                case .quick:
                    Section {
                        TextField("Назва (необов'язково)", text: $quickName)
                        TextField("Калорії, ккал", value: $quickKcal, format: .number)
                            .keyboardType(.numberPad)
                        TextField("Білок, г", value: $quickProtein, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Додати їжу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Додати") { save() }
                        .bold()
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        switch mode {
        case .reference: selected != nil
        case .quick: (quickKcal ?? 0) > 0
        }
    }

    private func save() {
        let entry: FoodEntry
        switch mode {
        case .reference:
            guard let selected else { return }
            entry = NutritionStore.entry(for: selected, grams: grams)
        case .quick:
            let name = quickName.trimmingCharacters(in: .whitespaces)
            entry = FoodEntry(name: name.isEmpty ? String(localized: "Прийом їжі") : name, kcal: quickKcal ?? 0, protein: quickProtein ?? 0)
        }
        NutritionStore.add(entry, in: context)
        Haptics.selection()
        dismiss()
    }
}

/// Weekly shopping list from 7 rotating menus.
struct ShoppingListView: View {
    let snapshot: ProfileSnapshot
    let targetKcal: Int
    let startVariant: Int
    @State private var checked: Set<String> = []

    var body: some View {
        let templates = MenuBuilder.orderedTemplates(NutritionStore.menus(), budget: snapshot.budget)
        let week = MenuBuilder.week(
            templates: templates, start: startVariant, foods: NutritionStore.foods(), targetKcal: targetKcal,
            mealsPerDay: snapshot.mealsPerDay, exclusions: snapshot.dietExclusions, budget: snapshot.budget
        )
        let items = MenuBuilder.shoppingList(week)
        List {
            Section {
                ForEach(items, id: \.food.id) { item in
                    Button {
                        if checked.contains(item.food.id) { checked.remove(item.food.id) } else { checked.insert(item.food.id) }
                    } label: {
                        HStack {
                            Image(systemName: checked.contains(item.food.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(checked.contains(item.food.id) ? Theme.Palette.success : Color.secondary)
                            Text(item.food.name)
                                .strikethrough(checked.contains(item.food.id))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(amount(item)).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("На 7 днів: меню чергуються, починаючи з обраного варіанту. Кількості округлені вгору.")
            }
        }
        .navigationTitle("Список покупок")
        .toolbar {
            ShareLink(item: shareText(items)) {
                Label("Поділитися", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func amount(_ item: MenuBuilder.ShoppingItem) -> String {
        if item.food.role == "egg", let units = item.units {
            return String(localized: "\(units) шт")
        }
        if item.grams >= 1000 {
            return String(localized: "\((item.grams / 1000).preciseText) кг")
        }
        return String(localized: "\(Int(item.grams)) г")
    }

    private func shareText(_ items: [MenuBuilder.ShoppingItem]) -> String {
        items.map { "• \($0.food.name) - \(amount($0))" }.joined(separator: "\n")
    }
}
