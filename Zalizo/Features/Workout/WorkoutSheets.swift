import SwiftData
import SwiftUI
import ZalizoCore

/// Replace an exercise on the fly: alternatives first, then the whole library.
struct ReplaceExerciseSheet: View {
    let performed: PerformedExercise
    let exercise: Exercise?
    let onPick: (Exercise) -> Void
    @Query private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    private var alternatives: [Exercise] {
        (exercise?.alternatives ?? []).compactMap { slug in exercises.first { $0.slug == slug } }
    }

    var body: some View {
        NavigationStack {
            List {
                if !alternatives.isEmpty {
                    Section("Альтернативи") {
                        ForEach(alternatives) { item in
                            Button { onPick(item) } label: { ExerciseRow(exercise: item) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        ExerciseLibraryView(onPick: onPick)
                    } label: {
                        Label("Уся бібліотека", systemImage: "books.vertical")
                    }
                }
            }
            .navigationTitle("Замінити «\(performed.exerciseName)»")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
            }
        }
    }
}

/// Which plates go on each side of the bar.
struct PlateCalculatorSheet: View {
    @State var weight: Double
    let settings: LoadSettings
    @Query private var appSettings: [AppSettings]

    init(initialWeight: Double, settings: LoadSettings) {
        _weight = State(initialValue: max(initialWeight, settings.barWeightKg))
        self.settings = settings
    }

    private var result: PlateCalculator.Result {
        PlateCalculator.load(target: weight, barWeight: settings.barWeightKg, plates: appSettings.first?.platesKg ?? Defaults.plates)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Калькулятор дисків").font(.title3.bold())
            BigStepper(title: "кг на штанзі", value: $weight, step: settings.barbellStepKg, range: settings.barWeightKg...500)
            PlateBarView(plates: result.perSide)
                .frame(height: 120)
            VStack(spacing: Theme.Spacing.xs) {
                if result.perSide.isEmpty {
                    Text("Лише гриф (\(settings.barWeightKg.kgText) кг)")
                } else {
                    Text("На кожну сторону: \(result.perSide.map(\.preciseText).joined(separator: " + ")) кг")
                        .font(.headline)
                }
                if !result.isExact {
                    Text("Точно \(weight.preciseText) кг не набрати - найближче \(result.achievedTotal.preciseText) кг")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.warning)
                }
                Text("Гриф \(settings.barWeightKg.kgText) кг. Набір дисків змінюється в Налаштуваннях.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}

/// Simple drawing of one side of a loaded bar.
struct PlateBarView: View {
    let plates: [Double]

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            HStack(spacing: 3) {
                Rectangle().fill(Color.secondary.opacity(0.5)).frame(width: 40, height: 10)
                Rectangle().fill(Color.secondary.opacity(0.7)).frame(width: 8, height: 26)
                ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(plate))
                        .frame(width: plate >= 5 ? 16 : 10, height: height * size(plate))
                        .overlay {
                            Text(plate.preciseText)
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(-90))
                                .fixedSize()
                                .foregroundStyle(.white)
                        }
                }
                Rectangle().fill(Color.secondary.opacity(0.5)).frame(height: 10)
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func size(_ plate: Double) -> CGFloat {
        switch plate {
        case 20...: 1
        case 15..<20: 0.88
        case 10..<15: 0.76
        case 5..<10: 0.58
        case 2.5..<5: 0.44
        default: 0.34
        }
    }

    /// Olympic colour convention.
    private func color(_ plate: Double) -> Color {
        switch plate {
        case 25: .red
        case 20: .blue
        case 15: .yellow
        case 10: .green
        default: .gray
        }
    }
}

/// Warm-up ramp for the current working weight.
struct WarmupSheet: View {
    let performed: PerformedExercise
    let model: WorkoutModel

    var body: some View {
        let plan = model.plan(for: performed)
        let working = performed.orderedSets.filter { !$0.isWarmup }.map(\.weightKg).max() ?? 0
        let bar: Double? = if case .barbell = plan.load { model.loadSettings.barWeightKg } else { nil }
        let sets = WarmupGenerator.sets(
            workingWeight: working, mechanic: .compound, barWeight: bar,
            step: ProgressionEngine.roundingStep(for: plan, settings: model.loadSettings)
        )
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Розминка до \(working.preciseText) кг").font(.title3.bold())
            if sets.isEmpty {
                Text("Для цієї ваги окрема розминка не потрібна - зроби 1 легкий підхід на 10-12 повторів.")
            } else {
                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                    HStack {
                        Text("\(index + 1).").foregroundStyle(.secondary)
                        Text("\(set.weight.preciseText) кг × \(set.reps)").font(.headline.monospacedDigit())
                    }
                }
            }
            Text("Відпочинок між розминочними підходами - до хвилини. Розминка не повинна втомлювати.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Post-workout summary: duration, tonnage, sets, records, comparison, feeling, note.
struct WorkoutSummaryView: View {
    let model: WorkoutModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feeling = 3
    @State private var note = ""

    var body: some View {
        let stats = model.stats
        let change = stats.tonnageChangePercent(vs: model.previousStats)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Theme.Spacing.s) {
                        StatTile(title: "Тривалість", value: durationText(stats), systemImage: "stopwatch")
                        StatTile(title: "Тоннаж", value: Int(stats.tonnage).groupedText, unit: "кг", systemImage: "scalemass")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    HStack(spacing: Theme.Spacing.s) {
                        StatTile(title: "Робочих підходів", value: "\(stats.workingSets)", systemImage: "number")
                        StatTile(title: "Вправ", value: "\(stats.exercises)", systemImage: "dumbbell")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                if let change {
                    Section("Порівняно з минулим разом") {
                        Label {
                            Text("Тоннаж \(change >= 0 ? "+" : "")\(change.kgText) %")
                        } icon: {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(change >= 0 ? Theme.Palette.success : Theme.Palette.warning)
                        }
                    }
                }
                if !model.records.isEmpty {
                    Section("Рекорди") {
                        ForEach(model.records) { record in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(record.text)
                                    Text(record.exerciseName).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            }
                        }
                    }
                }
                Section("Як почуваєшся?") {
                    Picker("Самопочуття", selection: $feeling) {
                        ForEach(1...5, id: \.self) { value in
                            Text(FeelingText.title(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Нотатка до тренування", text: $note, axis: .vertical)
                }
                if !model.hasCompletedSets {
                    Section {
                        Text("Немає жодного виконаного підходу - тренування не буде збережено в історії.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Тренування завершено")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Зберегти") {
                        if model.hasCompletedSets {
                            model.finish(feeling: feeling, note: note)
                        } else {
                            model.discard()
                        }
                        onDone()
                    }
                    .bold()
                }
            }
        }
    }

    private func durationText(_ stats: WorkoutStats) -> String {
        let (hours, minutes) = stats.hoursMinutes
        return hours > 0 ? String(localized: "\(hours) год \(minutes) хв") : String(localized: "\(minutes) хв")
    }
}

enum FeelingText {
    static func title(_ value: Int) -> LocalizedStringResource {
        switch value {
        case 1: "Важко"
        case 2: "Так собі"
        case 3: "Норм"
        case 4: "Добре"
        default: "Чудово"
        }
    }
}
