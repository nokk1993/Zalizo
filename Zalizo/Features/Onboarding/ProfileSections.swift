import SwiftUI
import ZalizoCore

// Question blocks shared by onboarding and Profile → "Мої дані".
// Each edits a `ProfileSnapshot` binding; persistence is the caller's job.

struct QuestionHeader: View {
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

struct WelcomeSection: View {
    @ScaledMetric(relativeTo: .largeTitle) private var brandSize: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            WelcomeOrb()
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.l)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Привіт! Це")
                    .font(.title.weight(.light))
                    .foregroundStyle(.secondary)
                Text("«Зал»")
                    .font(.system(size: brandSize, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("Тренуйся розумно. Рости щотижня.")
                    .font(.title3.weight(.light))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                WelcomeRow(systemImage: "wand.and.stars", text: "Кілька коротких питань - і додаток порахує твою норму калорій і БЖВ, складе програму тренувань і підкаже робочі ваги на кожне тренування.")
                WelcomeRow(systemImage: "lock.shield", text: "Відповіді можна змінити будь-коли: Профіль → Мої дані. Усі дані зберігаються тільки на цьому телефоні.")
            }
            .cardStyle()

            DisclaimerBox()
        }
    }
}

/// Soft lime glow behind a glass disc with a thin athlete symbol.
private struct WelcomeOrb: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.Palette.accent.opacity(0.55), Theme.Palette.accent.opacity(0)],
                    center: .center, startRadius: 0, endRadius: 130
                ))
                .frame(width: 260, height: 260)
                .blur(radius: 18)
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color.white)
                .frame(width: 148, height: 148)
                .glassEffect(.regular, in: Circle())
        }
        .accessibilityHidden(true)
    }
}

private struct WelcomeRow: View {
    let systemImage: String
    let text: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconBadge(systemImage: systemImage, tint: Theme.Palette.accent, size: 34)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DisclaimerBox: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconBadge(systemImage: "cross.case", tint: Theme.Palette.warning, size: 34)
            Text("Інформація в додатку не є медичною порадою. Якщо під час вправи з'явився біль - зупинись. При хронічних захворюваннях або проблемах зі здоров'ям порадься з лікарем.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(tint: Theme.Palette.warning)
        .accessibilityElement(children: .combine)
    }
}

struct BodySection: View {
    @Binding var snapshot: ProfileSnapshot

    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -Defaults.ageYears, to: .now) ?? .now
    }

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let oldest = calendar.date(byAdding: .year, value: -90, to: .now) ?? .distantPast
        let youngest = calendar.date(byAdding: .year, value: -14, to: .now) ?? .now
        return oldest...youngest
    }

    private var birthDate: Binding<Date> {
        Binding(get: { snapshot.birthDate ?? Self.defaultBirthDate }, set: { snapshot.birthDate = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            QuestionHeader(title: "Стать", subtitle: "Потрібна для формули обміну речовин")
            HStack(spacing: Theme.Spacing.m) {
                ForEach(Sex.allCases, id: \.self) { sex in
                    OptionCard(title: sex.title, isSelected: snapshot.sex == sex) { snapshot.sex = sex }
                }
            }

            QuestionHeader(title: "Дата народження")
            HStack {
                DatePicker("Дата народження", selection: birthDate, in: birthDateRange, displayedComponents: .date)
                    .labelsHidden()
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Вік").eyebrow()
                    Text("\(snapshot.ageYears())")
                        .font(.title.weight(.light).monospacedDigit())
                        .foregroundStyle(snapshot.birthDate == nil ? Color.secondary : Color.primary)
                }
                .accessibilityElement(children: .combine)
            }
            .cardStyle()

            QuestionHeader(title: "Зріст")
            HeightWheel(heightCm: $snapshot.heightCm)
                .cardStyle(inset: Theme.Spacing.s)

            QuestionHeader(title: "Поточна вага", subtitle: "Зважуйся зранку натще - так найточніше")
            WeightWheel(weightKg: $snapshot.weightKg)
                .cardStyle(inset: Theme.Spacing.s)
        }
    }
}

struct GoalSection: View {
    @Binding var snapshot: ProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            QuestionHeader(title: "Досвід тренувань")
            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                OptionCard(title: level.title, subtitle: level.subtitle, isSelected: snapshot.experience == level) {
                    snapshot.experience = level
                }
            }
            QuestionHeader(title: "Ціль").padding(.top, Theme.Spacing.l)
            ForEach(TrainingGoal.allCases, id: \.self) { goal in
                OptionCard(title: goal.title, subtitle: goal.subtitle, systemImage: goal.systemImage, isSelected: snapshot.goal == goal) {
                    snapshot.goal = goal
                }
            }
        }
    }
}

struct ScheduleSection: View {
    @Binding var snapshot: ProfileSnapshot
    private let durations = [45, 60, 75, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            QuestionHeader(title: "У які дні тренуєшся?", subtitle: "Для набору маси оптимально 3 дні з днем відпочинку між ними")
            FlowLayout {
                ForEach(Weekday.allCases, id: \.self) { day in
                    ChipToggle(title: day.shortTitle, isOn: snapshot.trainingDays.contains(day)) { toggle(day) }
                }
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Тренувань на тиждень").font(.subheadline).foregroundStyle(.secondary)
                    if snapshot.trainingDays.isEmpty {
                        Text("Обери хоча б один день").font(.footnote).foregroundStyle(Theme.Palette.danger)
                    }
                }
                Spacer()
                MetricText("\(snapshot.trainingDays.count)", size: 34)
                    .foregroundStyle(snapshot.trainingDays.isEmpty ? Theme.Palette.danger : Color.primary)
            }
            .cardStyle()
            .accessibilityElement(children: .combine)

            QuestionHeader(title: "Скільки часу на тренування?")
            PillPicker(selection: $snapshot.sessionMinutes, options: durations) { "\($0) хв" }
        }
    }

    private func toggle(_ day: Weekday) {
        if let index = snapshot.trainingDays.firstIndex(of: day) {
            snapshot.trainingDays.remove(at: index)
        } else {
            snapshot.trainingDays.append(day)
            snapshot.trainingDays.sort()
        }
    }
}

struct ActivitySection: View {
    @Binding var snapshot: ProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            QuestionHeader(title: "Повсякденна активність", subtitle: "Без урахування тренувань - для розрахунку калорій")
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                OptionCard(title: level.title, subtitle: level.subtitle, systemImage: level.systemImage, isSelected: snapshot.activity == level) {
                    snapshot.activity = level
                }
            }
            Text("Коефіцієнт уже враховує близько трьох силових тренувань на тиждень, тому окремо калорії за тренування не додаються.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct EquipmentSection: View {
    @Binding var snapshot: ProfileSnapshot
    @Binding var dumbbellStepKg: Double

    private let selectable = Equipment.allCases.filter { $0 != .bodyweight }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            QuestionHeader(title: "Що є у твоєму залі?", subtitle: "Вправи без потрібного обладнання програма замінить альтернативами")
            ForEach(selectable, id: \.self) { item in
                OptionCard(title: item.title, systemImage: item.systemImage, isSelected: snapshot.equipment.contains(item)) {
                    toggle(item)
                }
            }

            if snapshot.equipment.contains(.dumbbells) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Stepper(value: $snapshot.dumbbellMaxKg, in: 4...80, step: 2) {
                        Text("Гантелі до \(snapshot.dumbbellMaxKg.kgText) кг")
                    }
                    Text("Крок гантелей").eyebrow()
                    PillPicker(selection: $dumbbellStepKg, options: [1.0, 2.0, 2.5]) { "\($0.preciseText) кг" }
                }
                .cardStyle()
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Toggle("Є маленькі диски 1,25 кг", isOn: $snapshot.hasMicroPlates)
                Text(snapshot.hasMicroPlates ? "Найменший крок штанги - 2,5 кг" : "Найменший крок штанги - 5 кг")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .cardStyle()
        }
    }

    private func toggle(_ item: Equipment) {
        if snapshot.equipment.contains(item) {
            snapshot.equipment.remove(item)
        } else {
            snapshot.equipment.insert(item)
        }
        snapshot.equipment.insert(.bodyweight)
    }
}

struct LimitationsSection: View {
    @Binding var snapshot: ProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            QuestionHeader(title: "Є обмеження або травми?", subtitle: "Вправи з ризиком для цих зон замінимо безпечнішими і пояснимо чому")
            OptionCard(title: "Немає обмежень", systemImage: "checkmark.seal", isSelected: snapshot.limitations.isEmpty) {
                snapshot.limitations = []
            }
            ForEach(InjuryArea.allCases, id: \.self) { area in
                OptionCard(title: area.title, systemImage: area.systemImage, isSelected: snapshot.limitations.contains(area)) {
                    if snapshot.limitations.contains(area) {
                        snapshot.limitations.remove(area)
                    } else {
                        snapshot.limitations.insert(area)
                    }
                }
            }
            Text("Якщо щось болить під час вправи - зупинись. Гострий або тривалий біль - привід звернутися до лікаря.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct NutritionPreferencesSection: View {
    @Binding var snapshot: ProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            QuestionHeader(title: "Що ти не їси?", subtitle: "Алергії, непереносимість або просто не любиш")
            FlowLayout {
                ForEach(DietExclusion.allCases, id: \.self) { item in
                    ChipToggle(title: item.title, isOn: snapshot.dietExclusions.contains(item)) {
                        if snapshot.dietExclusions.contains(item) {
                            snapshot.dietExclusions.remove(item)
                        } else {
                            snapshot.dietExclusions.insert(item)
                        }
                    }
                }
            }

            QuestionHeader(title: "Скільки разів на день зручно їсти?")
            PillPicker(selection: $snapshot.mealsPerDay, options: Array(3...6)) { "\($0)" }

            QuestionHeader(title: "Бюджет на продукти")
            VStack(spacing: Theme.Spacing.m) {
                ForEach(FoodBudget.allCases, id: \.self) { budget in
                    OptionCard(title: budget.title, subtitle: budget.subtitle, isSelected: snapshot.budget == budget) {
                        snapshot.budget = budget
                    }
                }
            }
        }
    }
}

struct TargetWeightSection: View {
    @Binding var snapshot: ProfileSnapshot

    private var summary: PlanSummary { PlanCalculator.summary(for: snapshot) }

    private var hasTarget: Binding<Bool> {
        Binding(
            get: { snapshot.targetWeightKg != nil },
            set: { isOn in
                if isOn {
                    snapshot.targetWeightKg = PlanCalculator.summary(for: snapshot).targetWeightKg
                } else {
                    snapshot.targetWeightKg = nil
                }
            }
        )
    }

    private var target: Binding<Double> {
        Binding(get: { snapshot.targetWeightKg ?? snapshot.weightKg }, set: { snapshot.targetWeightKg = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            QuestionHeader(title: "Цільова вага", subtitle: "Необов'язково - інакше запропонуємо розумну ціль")
            Toggle("Я знаю, скільки хочу важити", isOn: hasTarget)
                .cardStyle()

            if snapshot.targetWeightKg != nil {
                WeightWheel(weightKg: target)
                    .cardStyle(inset: Theme.Spacing.s)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Пропонуємо").eyebrow()
                    MetricText(summary.targetWeightKg.kgText, unit: "кг", size: 44)
                    Text("Це приблизно 16 тижнів набору в безпечному темпі. Після досягнення можна поставити нову ціль.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()
            }

            PaceInfo(summary: summary, weightKg: snapshot.weightKg)
        }
    }
}

struct PaceInfo: View {
    let summary: PlanSummary
    let weightKg: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            let range = summary.recommendedRatePercent
            let lower = weightKg * range.lowerBound / 100
            let upper = weightKg * range.upperBound / 100
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: "speedometer", tint: Theme.Palette.accent, size: 34)
                Text("Безпечний темп набору").font(.headline)
            }
            Text("\(range.lowerBound.preciseText)-\(range.upperBound.preciseText) % ваги на тиждень ≈ \(lower.preciseText)-\(upper.preciseText) кг")
            if summary.kgPerWeek > 0 {
                Text("Плануємо: +\(summary.kgPerWeek.preciseText) кг на тиждень")
                    .foregroundStyle(.secondary)
            }
            Text("Швидший набір - це здебільшого жир, а не м'язи.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

struct LiftsSection: View {
    @Binding var knowsLifts: Bool
    @Binding var lifts: [KeyLift: LiftResult]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            QuestionHeader(title: "Стартові робочі ваги", subtitle: "З відомих результатів порахуємо твій 1ПМ і робочі ваги")
            OptionCard(
                title: "Не знаю - підберемо на першому тренуванні",
                subtitle: "Почнеш з легкої ваги, а після підходу додаток підкаже, скільки додати",
                systemImage: "wand.and.stars",
                isSelected: !knowsLifts
            ) { knowsLifts = false }
            OptionCard(
                title: "Введу відомі результати",
                subtitle: "Наприклад: жим лежачи 70 кг × 10",
                systemImage: "list.number",
                isSelected: knowsLifts
            ) { knowsLifts = true }

            if knowsLifts {
                ForEach(KeyLift.allCases, id: \.self) { lift in
                    LiftRow(title: lift.title, result: binding(for: lift))
                }
                Text("Заповни лише ті вправи, які знаєш. Найточніше - результат на 3-10 повторень.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func binding(for lift: KeyLift) -> Binding<LiftResult> {
        Binding(
            get: { lifts[lift] ?? LiftResult(weightKg: 0, reps: 8) },
            set: { lifts[lift] = $0 }
        )
    }
}

private struct LiftRow: View {
    let title: LocalizedStringResource
    @Binding var result: LiftResult

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title).font(.headline)
            HStack {
                WeightField(weightKg: $result.weightKg)
                Spacer()
                Stepper(value: $result.reps, in: 1...20) {
                    Text("× \(result.reps)").font(.body.monospacedDigit())
                }
                .fixedSize()
            }
            if result.isValid {
                let estimate = result.estimatedOneRM()
                HStack(spacing: Theme.Spacing.s) {
                    GlowDot(color: estimate.isReliable ? Theme.Palette.accent : Theme.Palette.warning, size: 6)
                    Text("1ПМ ≈ \(estimate.value.kgText) кг\(estimate.isReliable ? "" : " (оцінка неточна: забагато повторень)")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }
}

/// Calories, macros, pace, forecast and program - onboarding summary and Profile → "Норми і прогноз".
struct PlanSummaryCard: View {
    let summary: PlanSummary
    let snapshot: ProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            CaloriesHero(summary: summary)
            MacrosCard(day: summary.targets.restDay)

            HStack(spacing: Theme.Spacing.s) {
                StatTile(title: "Вода", value: (Double(summary.targets.waterRestDayMl) / 1000).preciseText, unit: "л", systemImage: "drop.fill", tint: Theme.Palette.water)
                StatTile(title: "Клітковина", value: "\(summary.targets.fiberG)", unit: "г", systemImage: "leaf.fill", tint: Theme.Palette.success)
            }
            Text("У день тренування води більше: \((Double(summary.targets.waterTrainingDayMl) / 1000).preciseText) л")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForecastBlock(summary: summary, snapshot: snapshot)

            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: "dumbbell", tint: Theme.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Програма").eyebrow()
                    Text(ProgramTitles.title(slug: summary.recommendedProgramSlug)).font(.headline)
                }
            }
            .cardStyle()
            .accessibilityElement(children: .combine)

            DisclosureGroup {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Базовий обмін (Міффлін-Сан Жеор): \(Int(summary.targets.bmr.rounded()).groupedText) ккал")
                    Text("З урахуванням активності: \(Int(summary.targets.tdee.rounded()).groupedText) ккал. Коефіцієнт уже включає ~3 тренування на тиждень.")
                    Text("Профіцит: \(summary.targets.surplusPercent.preciseText) %")
                    Text("Білок \(snapshot.proteinPerKg.preciseText) г/кг, жири \(snapshot.fatPerKg.preciseText) г/кг (не менше 20 % калорій), решта - вуглеводи.")
                    Text("ІМТ: \(summary.bmi.kgText). Для людей з розвиненими м'язами ІМТ неточний - він не відрізняє м'язи від жиру.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.s)
            } label: {
                Text("Як це пораховано").font(.subheadline.weight(.medium))
            }
            .cardStyle()
        }
    }
}

/// Lime highlight: daily calories in big thin digits.
private struct CaloriesHero: View {
    let summary: PlanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Норма на день").eyebrow()
            MetricText(summary.targets.restDay.kcal.groupedText, unit: "ккал", size: 56)
            if summary.targets.trainingDay.kcal != summary.targets.restDay.kcal {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "dumbbell.fill").font(.caption)
                    Text("У день тренування: \(summary.targets.trainingDay.kcal.groupedText) ккал")
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .highlightCardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct MacrosCard: View {
    let day: NutritionCalculator.Macros

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("БЖВ").eyebrow()
            MacroRow(title: "Білок", grams: day.proteinG, percent: day.proteinPercent, color: Theme.Palette.protein)
            MacroRow(title: "Жири", grams: day.fatG, percent: day.fatPercent, color: Theme.Palette.fat)
            MacroRow(title: "Вуглеводи", grams: day.carbsG, percent: day.carbsPercent, color: Theme.Palette.carbs)
        }
        .cardStyle()
    }
}

private struct ForecastBlock: View {
    let summary: PlanSummary
    let snapshot: ProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: "calendar", tint: Theme.Palette.blue, size: 34)
                Text("Прогноз").font(.headline)
            }
            if let forecast = summary.forecast {
                Text("З \(snapshot.weightKg.kgText) до \(summary.targetWeightKg.kgText) кг при темпі \(summary.kgPerWeek.preciseText) кг/тижд ≈ \(Int(forecast.weeks.rounded())) тижн.")
                    .font(.title3.weight(.light))
                Text("Орієнтовно до \(forecast.targetDate.formatted(date: .long, time: .omitted)) - це ≈ \(forecast.workouts) тренувань при \(snapshot.sessionsPerWeek) на тиждень.")
                    .foregroundStyle(.secondary)
                if summary.isTargetSuggested {
                    Text("Ціль запропонована автоматично - її можна змінити в Профілі.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if summary.kgPerWeek == 0 {
                Text("Мета - утримувати вагу. Стеж за силою і замірами.")
            } else {
                Text("Цільова вага не більша за поточну - прогноз набору недоступний.")
            }
        }
        .cardStyle()
    }
}

private struct MacroRow: View {
    let title: LocalizedStringResource
    let grams: Int
    let percent: Double
    let color: Color

    private var fraction: Double { min(max(percent / 100, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                GlowDot(color: color)
                Text(title).font(.subheadline)
                Spacer()
                Text("\(grams) г").font(.title3.weight(.light).monospacedDigit())
                Text("\(Int(percent.rounded())) %")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .scaleEffect(x: max(fraction, 0.02), y: 1, anchor: .leading)
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
    }
}
