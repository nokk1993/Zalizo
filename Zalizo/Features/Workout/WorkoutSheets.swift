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
                    .glassRows()
                }
                Section {
                    NavigationLink {
                        ExerciseLibraryView(onPick: onPick)
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            IconBadge(systemImage: "books.vertical", tint: Theme.Palette.accent)
                            Text("Уся бібліотека")
                        }
                    }
                }
                .glassRows()
            }
            .zalScreen()
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
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Text("Калькулятор дисків").font(.title2.weight(.light))
                BigStepper(title: "кг на штанзі", value: $weight, step: settings.barbellStepKg, range: settings.barWeightKg...500)
                PlateBarView(plates: result.perSide)
                    .frame(height: 120)
                    .cardStyle()
                summary
            }
            .padding(Theme.Spacing.xl)
        }
        .zalScreen()
    }

    private var summary: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if result.perSide.isEmpty {
                Text("Лише гриф (\(settings.barWeightKg.kgText) кг)")
                    .font(.headline)
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
}

/// Simple drawing of one side of a loaded bar.
struct PlateBarView: View {
    let plates: [Double]

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            HStack(spacing: 3) {
                Capsule().fill(barGradient).frame(width: 40, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.6)).frame(width: 8, height: 26)
                ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color(plate))
                        .frame(width: plate >= 5 ? 16 : 10, height: height * size(plate))
                        .shadow(color: color(plate).opacity(0.4), radius: 4)
                        .overlay {
                            Text(plate.preciseText)
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(-90))
                                .fixedSize()
                                .foregroundStyle(labelColor(plate))
                        }
                }
                Capsule().fill(barGradient).frame(height: 10)
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

    private var barGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.25)], startPoint: .top, endPoint: .bottom)
    }

    /// App palette instead of Olympic colours: heavier plates are brighter.
    private func color(_ plate: Double) -> Color {
        switch plate {
        case 25: Theme.Palette.accent
        case 20: Theme.Palette.blue
        case 15: Theme.Palette.ice
        case 10: Color.white.opacity(0.85)
        default: Color.white.opacity(0.45)
        }
    }

    private func labelColor(_ plate: Double) -> Color {
        plate == 20 ? .white : Theme.Palette.onAccent
    }
}

/// Warm-up ramp for the current working weight.
struct WarmupSheet: View {
    let performed: PerformedExercise
    let model: WorkoutModel

    var body: some View {
        let plan = model.plan(for: performed)
        let working = performed.orderedSets.filter { !$0.isWarmup }.map(\.weightKg).max() ?? 0
        let bar: Double? = plan.load == .barbell ? model.loadSettings.barWeightKg : nil
        let sets = WarmupGenerator.sets(
            workingWeight: working, mechanic: .compound, barWeight: bar,
            step: ProgressionEngine.roundingStep(for: plan, settings: model.loadSettings)
        )
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("Розминка до \(working.preciseText) кг")
                    .font(.title2.weight(.light))
                if sets.isEmpty {
                    Text("Для цієї ваги окрема розминка не потрібна - зроби 1 легкий підхід на 10-12 повторів.")
                        .cardStyle()
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                            HStack(spacing: Theme.Spacing.m) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Palette.row, in: Circle())
                                Text("\(set.weight.preciseText) кг × \(set.reps)")
                                    .font(.title3.weight(.light).monospacedDigit())
                            }
                        }
                    }
                    .cardStyle()
                }
                Text("Відпочинок між розминочними підходами - до хвилини. Розминка не повинна втомлювати.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .zalScreen()
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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    SummaryHeadline(title: model.session.title, tonnage: stats.tonnage, change: change)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
                        StatTile(title: "Тривалість", value: durationText(stats), systemImage: "stopwatch")
                        StatTile(title: "Робочих підходів", value: "\(stats.workingSets)", systemImage: "number")
                        StatTile(title: "Вправ", value: "\(stats.exercises)", systemImage: "dumbbell")
                        StatTile(title: "Рекордів", value: "\(model.records.count)", systemImage: "trophy.fill")
                    }
                    if !model.records.isEmpty {
                        recordsSection
                    }
                    feelingSection
                    if !model.hasCompletedSets {
                        Text("Немає жодного виконаного підходу - тренування не буде збережено в історії.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .cardStyle(tint: Theme.Palette.warning)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .zalScreen()
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

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader("Рекорди")
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(model.records) { record in
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "trophy.fill", tint: Theme.Palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.text).font(.subheadline.weight(.semibold))
                            Text(record.exerciseName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .cardStyle()
        }
    }

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader("Як почуваєшся?")
            FlowLayout {
                ForEach(1...5, id: \.self) { value in
                    ChipToggle(title: FeelingText.title(value), isOn: feeling == value) {
                        withAnimation(.snappy) { feeling = value }
                    }
                }
            }
            TextField("Нотатка до тренування", text: $note, axis: .vertical)
                .lineLimit(2...6)
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.row, in: .rect(cornerRadius: Theme.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                }
        }
    }

    private func durationText(_ stats: WorkoutStats) -> String {
        let (hours, minutes) = stats.hoursMinutes
        return hours > 0 ? String(localized: "\(hours) год \(minutes) хв") : String(localized: "\(minutes) хв")
    }
}

/// Lime headline of the summary: total tonnage and the change against last time.
private struct SummaryHeadline: View {
    let title: String
    let tonnage: Double
    let change: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title).eyebrow()
            Text("Тоннаж").font(.title2.weight(.light))
            MetricText(Int(tonnage).groupedText, unit: "кг", size: 56)
            if let change {
                Label {
                    Text("\(change >= 0 ? "+" : "")\(change.kgText) % до минулого разу")
                } icon: {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .highlightCardStyle()
        .accessibilityElement(children: .combine)
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
