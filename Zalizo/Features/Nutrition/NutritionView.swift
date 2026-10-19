import SwiftData
import SwiftUI
import ZalizoCore

/// "Харчування" tab: diary with rings, water, menus scaled to the target, norms, tips.
struct NutritionView: View {
    enum Part: String, CaseIterable {
        case today, menu, norms, tips

        var title: LocalizedStringResource {
            switch self {
            case .today: "Сьогодні"
            case .menu: "Меню"
            case .norms: "Норми"
            case .tips: "Поради"
            }
        }
    }

    @Query private var profiles: [UserProfile]
    @Query(ProfileView.latestWeightDescriptor) private var latestWeights: [BodyWeightEntry]
    @State private var section: Part = .today

    private var snapshot: ProfileSnapshot {
        profiles.first.map { ProfileStore.snapshot(of: $0, currentWeightKg: latestWeights.first?.weightKg) } ?? ProfileSnapshot()
    }

    var body: some View {
        let summary = PlanCalculator.summary(for: snapshot)
        let isTrainingDay = NutritionStore.isTrainingDay(profile: snapshot)
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    Picker("Розділ", selection: $section) {
                        ForEach(Part.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .today:
                        DiarySection(targets: summary.targets, isTrainingDay: isTrainingDay)
                    case .menu:
                        MenuSection(snapshot: snapshot, targets: summary.targets, isTrainingDay: isTrainingDay)
                    case .norms:
                        NormsSection(summary: summary)
                    case .tips:
                        KnowledgeList(category: .nutrition)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Харчування")
        }
    }
}

// MARK: - Diary

private struct DiarySection: View {
    let targets: NutritionCalculator.Targets
    let isTrainingDay: Bool
    @Environment(\.modelContext) private var context
    @Query(sort: \NutritionLog.day, order: .reverse) private var logs: [NutritionLog]
    @State private var showAdd = false
    @State private var adaptive: AdaptiveCalories.Evaluation = .notDue

    private var today: NutritionLog? {
        logs.first { Calendar.current.isDateInToday($0.day) }
    }

    var body: some View {
        let macros = isTrainingDay ? targets.trainingDay : targets.restDay
        let water = isTrainingDay ? targets.waterTrainingDayMl : targets.waterRestDayMl
        VStack(spacing: Theme.Spacing.l) {
            if case .adjust(let proposal) = adaptive {
                AdaptiveCard(proposal: proposal) { accepted in
                    NutritionStore.resolve(proposal, accepted: accepted, in: context)
                    adaptive = .notDue
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(isTrainingDay ? LocalizedStringResource("Тренувальний день") : LocalizedStringResource("День відпочинку"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: Theme.Spacing.m) {
                    MacroRing(title: "Ккал", value: today?.kcal ?? 0, target: Double(macros.kcal), color: .accentColor, large: true)
                    VStack(spacing: Theme.Spacing.s) {
                        MacroBar(title: "Білок", value: today?.protein ?? 0, target: Double(macros.proteinG), color: Theme.Palette.protein)
                        MacroBar(title: "Жири", value: today?.fat ?? 0, target: Double(macros.fatG), color: Theme.Palette.fat)
                        MacroBar(title: "Вуглеводи", value: today?.carbs ?? 0, target: Double(macros.carbsG), color: Theme.Palette.carbs)
                    }
                }
            }
            .cardStyle()

            WaterCard(ml: today?.waterMl ?? 0, target: water) { delta in
                NutritionStore.addWater(delta, in: context)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text("Їжа за сьогодні").font(.headline)
                    Spacer()
                    Button {
                        showAdd = true
                    } label: {
                        Label("Додати", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                }
                if let entries = today?.entries.sorted(by: { $0.time < $1.time }), !entries.isEmpty {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.name)
                                Text(entryDetails(entry)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(entry.kcal)) ккал").monospacedDigit()
                            Button {
                                context.delete(entry)
                                try? context.save()
                            } label: {
                                Image(systemName: "minus.circle").foregroundStyle(Theme.Palette.danger)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Видалити"))
                        }
                        Divider()
                    }
                } else {
                    Text("Додавай їжу вручну (ккал і білок) або з довідника продуктів.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .cardStyle()
        }
        .sheet(isPresented: $showAdd) { AddFoodSheet() }
        .task { adaptive = NutritionStore.adaptiveEvaluation(in: context) }
    }

    private func entryDetails(_ entry: FoodEntry) -> String {
        let grams = entry.grams.map { "\(Int($0)) г · " } ?? ""
        return String(localized: "\(grams)Б \(Int(entry.protein.rounded())) · Ж \(Int(entry.fat.rounded())) · В \(Int(entry.carbs.rounded()))")
    }
}

private struct AdaptiveCard: View {
    let proposal: AdaptiveCalories.Proposal
    let onResolve: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Корекція калорій", systemImage: "slider.horizontal.3").font(.headline)
            Text(message)
            Text("Темп за 2 тижні: \(proposal.weeklyGainPercent.preciseText) % ваги на тиждень (за ковзним середнім).")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(proposal.deltaKcal > 0 ? LocalizedStringResource("Додати \(proposal.deltaKcal) ккал") : LocalizedStringResource("Зменшити на \(-proposal.deltaKcal) ккал")) {
                    onResolve(true)
                }
                .buttonStyle(.zalPrimary)
                Button("Не зараз") { onResolve(false) }
                    .buttonStyle(.glass)
            }
        }
        .font(.subheadline)
        .cardStyle()
    }

    private var message: LocalizedStringResource {
        switch proposal.reason {
        case .losing: "Вага не росте, а знижується. Пропонуємо додати \(proposal.deltaKcal) ккал на день."
        case .tooSlow: "Ти набираєш повільно - додаємо \(proposal.deltaKcal) ккал на день."
        case .tooFast: "Набір надто швидкий: частина набору - жир. Пропонуємо мінус \(-proposal.deltaKcal) ккал."
        }
    }
}

struct MacroRing: View {
    let title: LocalizedStringResource
    let value: Double
    let target: Double
    let color: Color
    var large = false

    var body: some View {
        let progress = target > 0 ? min(value / target, 1) : 0
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: large ? 12 : 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: large ? 12 : 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
            VStack(spacing: 0) {
                Text("\(Int(value))").font((large ? Font.title2 : .headline).bold().monospacedDigit())
                Text("з \(Int(target)) \(String(localized: title).lowercased())").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: large ? 130 : 80, height: large ? 130 : 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(Int(value)) з \(Int(target))"))
    }
}

struct MacroBar: View {
    let title: LocalizedStringResource
    let value: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text("\(Int(value.rounded()))/\(Int(target)) г").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: proxy.size.width * (target > 0 ? min(value / target, 1) : 0))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WaterCard: View {
    let ml: Int
    let target: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            MacroRing(title: "Мл", value: Double(ml), target: Double(target), color: Theme.Palette.water)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("Вода", systemImage: "drop.fill").font(.headline).foregroundStyle(Theme.Palette.water)
                HStack {
                    Button("+250 мл") {
                        onChange(250)
                        Haptics.selection()
                    }
                    .buttonStyle(.zalPrimary)
                    .tint(Theme.Palette.water)
                    Button("−250") { onChange(-250) }
                        .buttonStyle(.glass)
                        .disabled(ml == 0)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }
}

// MARK: - Menu

private struct MenuSection: View {
    let snapshot: ProfileSnapshot
    let targets: NutritionCalculator.Targets
    let isTrainingDay: Bool
    @State private var variant = 0
    @State private var trainingDayMenu: Bool?

    var body: some View {
        let templates = MenuBuilder.orderedTemplates(NutritionStore.menus(), budget: snapshot.budget)
        let useTraining = trainingDayMenu ?? isTrainingDay
        let kcal = useTraining ? targets.trainingDay.kcal : targets.restDay.kcal
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if templates.isEmpty {
                Text("Меню недоступні").foregroundStyle(.secondary)
            } else {
                let template = templates[variant % templates.count]
                let menu = MenuBuilder.build(
                    template, foods: NutritionStore.foods(), targetKcal: kcal, mealsPerDay: snapshot.mealsPerDay,
                    exclusions: snapshot.dietExclusions, budget: snapshot.budget
                )
                Picker("День", selection: Binding(get: { useTraining }, set: { trainingDayMenu = $0 })) {
                    Text("Відпочинок").tag(false)
                    Text("Тренування").tag(true)
                }
                .pickerStyle(.segmented)

                HStack {
                    VStack(alignment: .leading) {
                        Text(menu.name).font(.headline)
                        Text("Варіант \(variant % templates.count + 1) з \(templates.count) · ціль \(kcal.groupedText) ккал")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        variant += 1
                        Haptics.selection()
                    } label: {
                        Label("Інший варіант", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.glass)
                }

                ForEach(menu.meals, id: \.slot) { meal in
                    MealCard(meal: meal)
                }

                TotalsRow(totals: menu.totals, target: useTraining ? targets.trainingDay : targets.restDay)

                NavigationLink {
                    ShoppingListView(snapshot: snapshot, targetKcal: kcal, startVariant: variant % templates.count)
                } label: {
                    Label("Список покупок на тиждень", systemImage: "cart")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)

                Text("Грамовки - для сирих продуктів і сухих круп. Якщо щось не підходить - заміни на схожий продукт з тієї ж групи.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MealCard: View {
    let meal: PlannedMenu.Meal

    var body: some View {
        let totals = meal.totals
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(meal.slot.title).font(.headline)
                Spacer()
                Text("\(Int(totals.kcal)) ккал · Б \(Int(totals.protein)) Ж \(Int(totals.fat)) В \(Int(totals.carbs))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(meal.portions.enumerated()), id: \.offset) { _, portion in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(portion.food.name)
                        if let replaced = portion.replaced {
                            Text("замість: \(replaced)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(gramsText(portion)).monospacedDigit()
                }
                .font(.subheadline)
            }
        }
        .cardStyle()
    }

    private func gramsText(_ portion: PlannedMenu.Portion) -> String {
        if let unit = portion.food.unitGrams, portion.food.role == "egg" {
            return String(localized: "\(Int((portion.grams / unit).rounded())) шт")
        }
        return String(localized: "\(Int(portion.grams)) г")
    }
}

private struct TotalsRow: View {
    let totals: MacroTotals
    let target: NutritionCalculator.Macros

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Разом за день").font(.headline)
            Text("\(Int(totals.kcal)) ккал (ціль \(target.kcal))").monospacedDigit()
            Text("Білок \(Int(totals.protein)) г (ціль \(target.proteinG)) · Жири \(Int(totals.fat)) г · Вуглеводи \(Int(totals.carbs)) г · Клітковина \(Int(totals.fiber)) г")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Norms

private struct NormsSection: View {
    let summary: PlanSummary
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            NormTable(rest: summary.targets.restDay, training: summary.targets.trainingDay)
            if let profile = profiles.first {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Додаткові вуглеводи в день тренування").font(.headline)
                    Picker("Вуглеводи в день тренування", selection: Binding(get: { profile.trainingDayCarbBoostKcal }, set: {
                        profile.trainingDayCarbBoostKcal = $0
                        try? context.save()
                    })) {
                        Text("0").tag(0)
                        Text("+100").tag(100)
                        Text("+150").tag(150)
                        Text("+200").tag(200)
                    }
                    .pickerStyle(.segmented)
                    Text("Трохи більше вуглеводів у день тренування - більше енергії на тренуванні. Тижнева калорійність майже не зміниться.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()
            }
            HStack(spacing: Theme.Spacing.s) {
                StatTile(title: "Вода (відпочинок)", value: (Double(summary.targets.waterRestDayMl) / 1000).preciseText, unit: "л", systemImage: "drop.fill", tint: Theme.Palette.water)
                StatTile(title: "Вода (тренування)", value: (Double(summary.targets.waterTrainingDayMl) / 1000).preciseText, unit: "л", systemImage: "drop.fill", tint: Theme.Palette.water)
            }
            StatTile(title: "Клітковина", value: "\(summary.targets.fiberG)", unit: "г / день", systemImage: "leaf.fill", tint: Theme.Palette.carbs)
            NavigationLink {
                PlanDetailsView()
            } label: {
                Label("Як це пораховано і прогноз", systemImage: "info.circle")
            }
            Text("Норми перераховуються, коли змінюється вага або дані профілю (Профіль → Мої дані).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NormTable: View {
    let rest: NutritionCalculator.Macros
    let training: NutritionCalculator.Macros

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.l, verticalSpacing: Theme.Spacing.s) {
            GridRow {
                Text("")
                Text("Відпочинок").font(.caption.bold())
                Text("Тренування").font(.caption.bold())
            }
            row("Калорії", "\(rest.kcal.groupedText) ккал", "\(training.kcal.groupedText) ккал")
            row("Білок", "\(rest.proteinG) г · \(Int(rest.proteinPercent)) %", "\(training.proteinG) г · \(Int(training.proteinPercent)) %")
            row("Жири", "\(rest.fatG) г · \(Int(rest.fatPercent)) %", "\(training.fatG) г · \(Int(training.fatPercent)) %")
            row("Вуглеводи", "\(rest.carbsG) г · \(Int(rest.carbsPercent)) %", "\(training.carbsG) г · \(Int(training.carbsPercent)) %")
        }
        .font(.subheadline.monospacedDigit())
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func row(_ title: LocalizedStringResource, _ rest: String, _ training: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(rest)
            Text(training)
        }
    }
}

#Preview {
    NutritionView()
        .previewData()
}
