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
                PillPicker(selection: $mode, options: Mode.allCases) { $0.title }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("Спосіб"))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: 0, bottom: Theme.Spacing.xs, trailing: 0))

                switch mode {
                case .reference:
                    if let selected {
                        Section {
                            HStack(spacing: Theme.Spacing.m) {
                                IconBadge(systemImage: "fork.knife", tint: Theme.Palette.accent, size: 34)
                                Text(selected.name).font(.headline)
                            }
                            Stepper(value: $grams, in: 5...2000, step: grams < 50 ? 5 : 10) {
                                Text("\(Int(grams)) г")
                                    .font(.title3.weight(.light).monospacedDigit())
                            }
                            let macros = selected.macros(grams: grams)
                            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                                MetricText("\(Int(macros.kcal))", unit: "ккал", size: 32)
                                SelectedMacros(protein: macros.protein, fat: macros.fat, carbs: macros.carbs)
                            }
                            .accessibilityElement(children: .combine)
                            Button("Обрати інший продукт") { self.selected = nil }
                        }
                        .glassRows()
                    } else {
                        Section {
                            HStack(spacing: Theme.Spacing.s) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                TextField("Пошук продукту", text: $search)
                            }
                            ForEach(foods) { food in
                                Button {
                                    selected = food
                                    grams = food.unitGrams ?? 100
                                } label: {
                                    HStack {
                                        Text(food.name).foregroundStyle(.primary)
                                        Spacer()
                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            Text("\(Int(food.kcal))")
                                                .font(.callout.weight(.light).monospacedDigit())
                                                .foregroundStyle(.primary)
                                            Text("ккал/100 г")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } footer: {
                            Text("Значення на 100 г: сирі продукти, сухі крупи.")
                        }
                        .glassRows()
                    }
                case .quick:
                    Section {
                        TextField("Назва (необов'язково)", text: $quickName)
                        TextField("Калорії, ккал", value: $quickKcal, format: .number)
                            .keyboardType(.numberPad)
                        TextField("Білок, г", value: $quickProtein, format: .number)
                            .keyboardType(.decimalPad)
                    } footer: {
                        Text("Достатньо калорій і білка - решту можна не рахувати.")
                    }
                    .glassRows()
                }
            }
            .zalScreen()
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
                        checked.formSymmetricDifference([item.food.id])
                    } label: {
                        ShoppingRow(name: item.food.name, amount: amount(item), isChecked: checked.contains(item.food.id))
                    }
                    .accessibilityAddTraits(checked.contains(item.food.id) ? [.isSelected] : [])
                }
            } footer: {
                Text("На 7 днів: меню чергуються, починаючи з обраного варіанту. Кількості округлені вгору.")
            }
            .glassRows()
        }
        .zalScreen()
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

/// "● Б 24,5  ● Ж 3  ● В 0" for the selected portion.
private struct SelectedMacros: View {
    let protein: Double
    let fat: Double
    let carbs: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            item("Б \(protein.kgText)", color: Theme.Palette.protein)
            item("Ж \(fat.kgText)", color: Theme.Palette.fat)
            item("В \(carbs.kgText)", color: Theme.Palette.carbs)
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private func item(_ text: LocalizedStringResource, color: Color) -> some View {
        HStack(spacing: 5) {
            GlowDot(color: color, size: 6)
            Text(text)
        }
    }
}

private struct ShoppingRow: View {
    let name: String
    let amount: String
    let isChecked: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(isChecked ? 0 : 0.25), lineWidth: 1.5)
                if isChecked {
                    Circle().fill(Theme.Palette.accent)
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.Palette.onAccent)
                }
            }
            .frame(width: 24, height: 24)
            .shadow(color: Theme.Palette.accent.opacity(isChecked ? 0.5 : 0), radius: 6)
            .accessibilityHidden(true)
            Text(name)
                .strikethrough(isChecked)
                .foregroundStyle(isChecked ? Color.secondary : Color.primary)
            Spacer()
            Text(amount)
                .font(.callout.weight(.light).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .animation(.snappy(duration: 0.2), value: isChecked)
    }
}
