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
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    PillPicker(selection: $section, options: Part.allCases) { $0.title }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("Розділ"))

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
            .zalScreen()
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

            CaloriesCard(log: today, macros: macros, isTrainingDay: isTrainingDay)

            WaterCard(ml: today?.waterMl ?? 0, target: water) { delta in
                NutritionStore.addWater(delta, in: context)
            }

            foodCard
        }
        .sheet(isPresented: $showAdd) { AddFoodSheet() }
        .task { adaptive = NutritionStore.adaptiveEvaluation(in: context) }
    }

    private var foodCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Щоденник").eyebrow()
                    Text("Їжа за сьогодні").font(.title3.weight(.semibold))
                }
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    Label("Додати", systemImage: "plus")
                }
                .buttonStyle(.zalPrimary)
            }
            if let entries = today?.entries.sorted(by: { $0.time < $1.time }), !entries.isEmpty {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(entries) { entry in
                        FoodEntryRow(name: entry.name, details: entryDetails(entry), kcal: entry.kcal) {
                            context.delete(entry)
                            try? context.save()
                        }
                        if entry.id != entries.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            } else {
                Text("Додавай їжу вручну (ккал і білок) або з довідника продуктів.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private func entryDetails(_ entry: FoodEntry) -> String {
        let grams = entry.grams.map { "\(Int($0)) г · " } ?? ""
        return String(localized: "\(grams)Б \(Int(entry.protein.rounded())) · Ж \(Int(entry.fat.rounded())) · В \(Int(entry.carbs.rounded()))")
    }
}

/// Big lime calorie gauge with three macro rings below.
private struct CaloriesCard: View {
    let log: NutritionLog?
    let macros: NutritionCalculator.Macros
    let isTrainingDay: Bool

    private var eaten: Double { log?.kcal ?? 0 }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            HStack(spacing: 6) {
                GlowDot(color: isTrainingDay ? Theme.Palette.accent : Theme.Palette.blue, size: 6)
                Text(isTrainingDay ? LocalizedStringResource("Тренувальний день") : LocalizedStringResource("День відпочинку"))
                    .eyebrow()
                Spacer()
            }

            gauge

            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                MacroRing(title: "Білок", value: log?.protein ?? 0, target: Double(macros.proteinG), color: Theme.Palette.protein)
                MacroRing(title: "Жири", value: log?.fat ?? 0, target: Double(macros.fatG), color: Theme.Palette.fat)
                MacroRing(title: "Вуглеводи", value: log?.carbs ?? 0, target: Double(macros.carbsG), color: Theme.Palette.carbs)
            }
            .frame(maxWidth: .infinity)
        }
        .cardStyle(inset: Theme.Spacing.xl)
    }

    private var gauge: some View {
        let target = Double(macros.kcal)
        return ProgressRing(progress: target > 0 ? eaten / target : 0, lineWidth: 16, tint: Theme.Palette.accent, isGauge: true) {
            VStack(spacing: 2) {
                MetricText("\(Int(eaten))", size: 46)
                Text("з \(macros.kcal.groupedText) ккал")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                remaining
                    .font(.caption.weight(.semibold))
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
        .frame(width: 230, height: 230)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Ккал"))
        .accessibilityValue(Text("\(Int(eaten)) з \(macros.kcal)"))
    }

    @ViewBuilder private var remaining: some View {
        let left = Int((Double(macros.kcal) - eaten).rounded())
        if left >= 0 {
            Text("залишилось \(left.groupedText)")
                .foregroundStyle(Theme.Palette.accent)
        } else {
            Text("+\((-left).groupedText) понад норму")
                .foregroundStyle(Theme.Palette.warning)
        }
    }
}

private struct FoodEntryRow: View {
    let name: String
    let details: String
    let kcal: Double
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconBadge(systemImage: "fork.knife", tint: Theme.Palette.accent, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.medium))
                Text(details)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.s)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(kcal))")
                    .font(.title3.weight(.light).monospacedDigit())
                Text("ккал")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.body)
                    .foregroundStyle(Theme.Palette.danger)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Видалити"))
        }
    }
}

private struct AdaptiveCard: View {
    let proposal: AdaptiveCalories.Proposal
    let onResolve: (Bool) -> Void

    private var tint: Color {
        proposal.deltaKcal > 0 ? Theme.Palette.blue : Theme.Palette.warning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: "slider.horizontal.3", tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Раз на 2 тижні").eyebrow()
                    Text("Корекція калорій").font(.headline)
                }
            }
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Темп за 2 тижні: \(proposal.weeklyGainPercent.preciseText) % ваги на тиждень (за ковзним середнім).")
                .font(.caption)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.s) {
                    acceptButton
                    laterButton
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    acceptButton
                    laterButton
                }
            }
        }
        .cardStyle(tint: tint)
    }

    private var acceptButton: some View {
        Button(proposal.deltaKcal > 0 ? LocalizedStringResource("Додати \(proposal.deltaKcal) ккал") : LocalizedStringResource("Зменшити на \(-proposal.deltaKcal) ккал")) {
            onResolve(true)
        }
        .buttonStyle(.zalPrimary)
    }

    private var laterButton: some View {
        Button("Не зараз") { onResolve(false) }
            .buttonStyle(.glass)
    }

    private var message: LocalizedStringResource {
        switch proposal.reason {
        case .losing: "Вага не росте, а знижується. Пропонуємо додати \(proposal.deltaKcal) ккал на день."
        case .tooSlow: "Ти набираєш повільно - додаємо \(proposal.deltaKcal) ккал на день."
        case .tooFast: "Набір надто швидкий: частина набору - жир. Пропонуємо мінус \(-proposal.deltaKcal) ккал."
        }
    }
}

/// Small glowing ring with the eaten grams in the center, title and target below.
struct MacroRing: View {
    let title: LocalizedStringResource
    let value: Double
    let target: Double
    let color: Color
    var large = false

    var body: some View {
        let progress = target > 0 ? min(value / target, 1) : 0
        VStack(spacing: Theme.Spacing.s) {
            ProgressRing(progress: progress, lineWidth: large ? 14 : 6, tint: color) {
                Text("\(Int(value.rounded()))")
                    .font(.system(size: large ? 34 : 18, weight: .light).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, Theme.Spacing.xs)
            }
            .frame(width: large ? 130 : 72, height: large ? 130 : 72)
            VStack(spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("з \(Int(target)) г")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(Int(value)) з \(Int(target))"))
    }
}

/// Thin glowing bar: value of target grams.
struct MacroBar: View {
    let title: LocalizedStringResource
    let value: Double
    let target: Double
    let color: Color

    var body: some View {
        let fraction = target > 0 ? min(value / target, 1) : 0
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                GlowDot(color: color, size: 6)
                Text(title).font(.footnote.weight(.medium))
                Spacer()
                Text("\(Int(value.rounded()))")
                    .font(.subheadline.weight(.light).monospacedDigit())
                Text("/ \(Int(target)) г")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: fraction > 0 ? max(proxy.size.width * fraction, 6) : 0)
                        .shadow(color: color.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WaterCard: View {
    let ml: Int
    let target: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            ProgressRing(progress: target > 0 ? Double(ml) / Double(target) : 0, lineWidth: 8, tint: Theme.Palette.water) {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Palette.water)
            }
            .frame(width: 76, height: 76)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Вода").eyebrow()
                MetricText(ml.groupedText, unit: "мл", size: 32)
                Text("з \(target.groupedText) мл")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.s) {
                Button {
                    onChange(250)
                    Haptics.selection()
                } label: {
                    Text("+250")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.primary)
                        .frame(width: 58, height: 58)
                        .glassEffect(.regular.tint(Theme.Palette.water.opacity(0.35)).interactive(), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("+250 мл"))

                CircleIconButton(systemImage: "minus", label: "-250 мл", size: 38) {
                    onChange(-250)
                }
                .disabled(ml == 0)
                .opacity(ml == 0 ? 0.4 : 1)
            }
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
                PillPicker(selection: Binding(get: { useTraining }, set: { trainingDayMenu = $0 }), options: [false, true]) { training -> LocalizedStringResource in
                    training ? "Тренування" : "Відпочинок"
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("День"))

                MenuHeader(
                    name: menu.name,
                    variant: variant % templates.count + 1,
                    count: templates.count,
                    kcal: kcal
                ) {
                    variant += 1
                    Haptics.selection()
                }

                ForEach(menu.meals, id: \.slot) { meal in
                    MealCard(meal: meal)
                }

                TotalsRow(totals: menu.totals, target: useTraining ? targets.trainingDay : targets.restDay)

                NavigationLink {
                    ShoppingListView(snapshot: snapshot, targetKcal: kcal, startVariant: variant % templates.count)
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "cart", tint: Theme.Palette.accent)
                        Text("Список покупок на тиждень")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .cardStyle()
                }
                .buttonStyle(.plain)

                Text("Грамовки - для сирих продуктів і сухих круп. Якщо щось не підходить - заміни на схожий продукт з тієї ж групи.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MenuHeader: View {
    let name: String
    let variant: Int
    let count: Int
    let kcal: Int
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Варіант \(variant) з \(count) · ціль \(kcal.groupedText) ккал").eyebrow()
            Text(name)
                .font(.title2.weight(.light))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onNext) {
                Label("Інший варіант", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.glass)
        }
        .cardStyle()
    }
}

private struct MealCard: View {
    let meal: PlannedMenu.Meal

    var body: some View {
        let totals = meal.totals
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(meal.slot.title).eyebrow()
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(totals.kcal))")
                        .font(.title3.weight(.light).monospacedDigit())
                    Text("ккал")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(Array(meal.portions.enumerated()), id: \.offset) { _, portion in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(portion.food.name)
                            if let replaced = portion.replaced {
                                Text("замість: \(replaced)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(gramsText(portion))
                            .font(.body.weight(.light).monospacedDigit())
                    }
                    .font(.subheadline)
                }
            }
            MacroDots(protein: totals.protein, fat: totals.fat, carbs: totals.carbs)
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

/// "● Б 40  ● Ж 15  ● В 80" in macro colors.
private struct MacroDots: View {
    let protein: Double
    let fat: Double
    let carbs: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            item("Б \(Int(protein))", color: Theme.Palette.protein)
            item("Ж \(Int(fat))", color: Theme.Palette.fat)
            item("В \(Int(carbs))", color: Theme.Palette.carbs)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func item(_ text: LocalizedStringResource, color: Color) -> some View {
        HStack(spacing: 5) {
            GlowDot(color: color, size: 6)
            Text(text)
        }
    }
}

private struct TotalsRow: View {
    let totals: MacroTotals
    let target: NutritionCalculator.Macros

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Разом за день").eyebrow()
            HStack(alignment: .firstTextBaseline) {
                MetricText(Int(totals.kcal).groupedText, unit: "ккал", size: 36)
                Spacer()
                Text("ціль \(target.kcal.groupedText)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            MacroBar(title: "Білок", value: totals.protein, target: Double(target.proteinG), color: Theme.Palette.protein)
            MacroBar(title: "Жири", value: totals.fat, target: Double(target.fatG), color: Theme.Palette.fat)
            MacroBar(title: "Вуглеводи", value: totals.carbs, target: Double(target.carbsG), color: Theme.Palette.carbs)
            Text("Клітковина \(Int(totals.fiber)) г")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
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
                carbBoostCard(profile)
            }
            HStack(spacing: Theme.Spacing.s) {
                StatTile(title: "Вода (відпочинок)", value: (Double(summary.targets.waterRestDayMl) / 1000).preciseText, unit: "л", systemImage: "drop.fill", tint: Theme.Palette.water)
                StatTile(title: "Вода (тренування)", value: (Double(summary.targets.waterTrainingDayMl) / 1000).preciseText, unit: "л", systemImage: "drop.fill", tint: Theme.Palette.water)
            }
            StatTile(title: "Клітковина", value: "\(summary.targets.fiberG)", unit: "г / день", systemImage: "leaf.fill", tint: Theme.Palette.accent)
            NavigationLink {
                PlanDetailsView()
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    IconBadge(systemImage: "info.circle", tint: Theme.Palette.blue)
                    Text("Як це пораховано і прогноз")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .cardStyle()
            }
            .buttonStyle(.plain)
            Text("Норми перераховуються, коли змінюється вага або дані профілю (Профіль → Мої дані).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func carbBoostCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Додаткові вуглеводи в день тренування").font(.headline)
            PillPicker(
                selection: Binding(get: { profile.trainingDayCarbBoostKcal }, set: {
                    profile.trainingDayCarbBoostKcal = $0
                    try? context.save()
                }),
                options: [0, 100, 150, 200]
            ) { value -> LocalizedStringResource in
                value == 0 ? "0 ккал" : "+\(value) ккал"
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Вуглеводи в день тренування"))
            Text("Трохи більше вуглеводів у день тренування - більше енергії на тренуванні. Тижнева калорійність майже не зміниться.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

private struct NormTable: View {
    let rest: NutritionCalculator.Macros
    let training: NutritionCalculator.Macros

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Денна норма").font(.title3.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.m) {
                GridRow {
                    Text("")
                    columnHeader("Відпочинок", color: Theme.Palette.blue)
                    columnHeader("Тренування", color: Theme.Palette.accent)
                }
                Divider().overlay(Color.white.opacity(0.06))
                row("Калорії", "\(rest.kcal.groupedText) ккал", "\(training.kcal.groupedText) ккал")
                row("Білок", "\(rest.proteinG) г · \(Int(rest.proteinPercent)) %", "\(training.proteinG) г · \(Int(training.proteinPercent)) %")
                row("Жири", "\(rest.fatG) г · \(Int(rest.fatPercent)) %", "\(training.fatG) г · \(Int(training.fatPercent)) %")
                row("Вуглеводи", "\(rest.carbsG) г · \(Int(rest.carbsPercent)) %", "\(training.carbsG) г · \(Int(training.carbsPercent)) %")
            }
        }
        .cardStyle()
    }

    private func columnHeader(_ title: LocalizedStringResource, color: Color) -> some View {
        HStack(spacing: 5) {
            GlowDot(color: color, size: 6)
            Text(title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func row(_ title: LocalizedStringResource, _ rest: String, _ training: String) -> some View {
        GridRow {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(rest)
                .font(.callout.weight(.light).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(training)
                .font(.callout.weight(.light).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

#Preview {
    NutritionView()
        .previewData()
        .themed()
}
