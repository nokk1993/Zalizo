import SwiftUI
import ZalizoCore

// Question blocks shared by onboarding and Profile → "Мої дані".
// Each edits a `ProfileSnapshot` binding; persistence is the caller's job.

struct QuestionHeader: View {
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(.title3.bold())
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

struct WelcomeSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xl)
            Text("Привіт! Це «Зал»")
                .font(.largeTitle.bold())
            Text("Кілька коротких питань - і додаток порахує твою норму калорій і БЖВ, складе програму тренувань і підкаже робочі ваги на кожне тренування.")
                .font(.body)
            Text("Відповіді можна змінити будь-коли: Профіль → Мої дані. Усі дані зберігаються тільки на цьому телефоні.")
                .font(.callout)
                .foregroundStyle(.secondary)
            DisclaimerBox()
        }
    }
}

struct DisclaimerBox: View {
    var body: some View {
        Label {
            Text("Інформація в додатку не є медичною порадою. Якщо під час вправи з'явився біль - зупинись. При хронічних захворюваннях або проблемах зі здоров'ям порадься з лікарем.")
                .font(.footnote)
        } icon: {
            Image(systemName: "cross.case")
                .foregroundStyle(Theme.Palette.warning)
        }
        .cardStyle()
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
                Text("Вік: \(snapshot.ageYears())")
                    .font(.headline)
                    .foregroundStyle(snapshot.birthDate == nil ? Color.secondary : Color.primary)
            }
            .cardStyle()

            QuestionHeader(title: "Зріст")
            HeightWheel(heightCm: $snapshot.heightCm)

            QuestionHeader(title: "Поточна вага", subtitle: "Зважуйся зранку натще - так найточніше")
            WeightWheel(weightKg: $snapshot.weightKg)
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
            Text("Тренувань на тиждень: \(snapshot.trainingDays.count)")
                .font(.headline)
                .foregroundStyle(snapshot.trainingDays.isEmpty ? Theme.Palette.danger : Color.primary)
            if snapshot.trainingDays.isEmpty {
                Text("Обери хоча б один день").font(.footnote).foregroundStyle(Theme.Palette.danger)
            }

            QuestionHeader(title: "Скільки часу на тренування?")
            Picker("Тривалість", selection: $snapshot.sessionMinutes) {
                ForEach(durations, id: \.self) { Text("\($0) хв").tag($0) }
            }
            .pickerStyle(.segmented)
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
                    Text("Крок гантелей").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Крок гантелей", selection: $dumbbellStepKg) {
                        Text("1 кг").tag(1.0)
                        Text("2 кг").tag(2.0)
                        Text("2,5 кг").tag(2.5)
                    }
                    .pickerStyle(.segmented)
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
            Picker("Прийомів їжі", selection: $snapshot.mealsPerDay) {
                ForEach(3...6, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)

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
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Пропонуємо: \(summary.targetWeightKg.kgText) кг")
                        .font(.title3.bold())
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
            Label("Безпечний темп набору", systemImage: "speedometer").font(.headline)
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
                Text("1ПМ ≈ \(estimate.value.kgText) кг\(estimate.isReliable ? "" : " (оцінка неточна: забагато повторень)")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Норма на день").font(.subheadline).foregroundStyle(.secondary)
                Text("\(summary.targets.restDay.kcal.groupedText) ккал")
                    .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
                if summary.targets.trainingDay.kcal != summary.targets.restDay.kcal {
                    Text("У день тренування: \(summary.targets.trainingDay.kcal.groupedText) ккал")
                        .font(.subheadline)
                }
            }
            .cardStyle()

            HStack(spacing: Theme.Spacing.s) {
                MacroTile(title: "Білок", grams: summary.targets.restDay.proteinG, percent: summary.targets.restDay.proteinPercent, color: Theme.Palette.protein)
                MacroTile(title: "Жири", grams: summary.targets.restDay.fatG, percent: summary.targets.restDay.fatPercent, color: Theme.Palette.fat)
                MacroTile(title: "Вуглеводи", grams: summary.targets.restDay.carbsG, percent: summary.targets.restDay.carbsPercent, color: Theme.Palette.carbs)
            }

            HStack(spacing: Theme.Spacing.s) {
                StatTile(title: "Вода", value: (Double(summary.targets.waterRestDayMl) / 1000).preciseText, unit: "л", systemImage: "drop.fill", tint: Theme.Palette.water)
                StatTile(title: "Клітковина", value: "\(summary.targets.fiberG)", unit: "г", systemImage: "leaf.fill", tint: Theme.Palette.carbs)
            }
            Text("У день тренування води більше: \((Double(summary.targets.waterTrainingDayMl) / 1000).preciseText) л")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForecastBlock(summary: summary, snapshot: snapshot)

            LabeledContent {
                Text(ProgramTitles.title(slug: summary.recommendedProgramSlug)).bold()
            } label: {
                Label("Програма", systemImage: "list.bullet.clipboard")
            }
            .cardStyle()

            DisclosureGroup("Як це пораховано") {
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
            }
            .cardStyle()
        }
    }
}

private struct ForecastBlock: View {
    let summary: PlanSummary
    let snapshot: ProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Прогноз", systemImage: "calendar").font(.headline)
            if let forecast = summary.forecast {
                Text("З \(snapshot.weightKg.kgText) до \(summary.targetWeightKg.kgText) кг при темпі \(summary.kgPerWeek.preciseText) кг/тижд ≈ \(Int(forecast.weeks.rounded())) тижн.")
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

private struct MacroTile: View {
    let title: LocalizedStringResource
    let grams: Int
    let percent: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(grams) г").font(.title3.bold().monospacedDigit())
            Text("\(Int(percent.rounded())) %").font(.caption2).foregroundStyle(.secondary)
            Capsule().fill(color).frame(height: 4)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.control))
        .accessibilityElement(children: .combine)
    }
}
