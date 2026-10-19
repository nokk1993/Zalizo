import SwiftData
import SwiftUI
import ZalizoCore

/// Sets, rep range, rest, RIR, note and exercise replacement for one planned exercise.
struct PlannedExerciseEditor: View {
    @Bindable var planned: PlannedExercise
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]
    @State private var showLibrary = false

    private var exercise: Exercise? { exercises.first { $0.slug == planned.exerciseSlug } }

    private var alternatives: [Exercise] {
        (exercise?.alternatives ?? []).compactMap { slug in exercises.first { $0.slug == slug } }
    }

    private let restOptions = [45, 60, 75, 90, 105, 120, 150, 180, 210, 240, 300]

    var body: some View {
        Form {
            Section {
                if let exercise {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                }
                LoadSummary(planned: planned)
            }
            .glassRows()

            Section("Навантаження") {
                Stepper(value: $planned.sets, in: 1...8) {
                    LabeledContent("Підходи") { Text("\(planned.sets)").monospacedDigit() }
                }
                Stepper(value: repMin, in: 1...50) {
                    LabeledContent(planned.progression == .timed ? "Мінімум, с" : "Повтори від") { Text("\(planned.repMin)").monospacedDigit() }
                }
                Stepper(value: repMax, in: 1...60) {
                    LabeledContent(planned.progression == .timed ? "Максимум, с" : "Повтори до") { Text("\(planned.repMax)").monospacedDigit() }
                }
                Picker("Відпочинок", selection: $planned.restSeconds) {
                    ForEach(restOptions, id: \.self) { Text(RestFormat.text($0)).tag($0) }
                    if !restOptions.contains(planned.restSeconds) {
                        Text(RestFormat.text(planned.restSeconds)).tag(planned.restSeconds)
                    }
                }
                Picker("Запас повторів (RIR)", selection: $planned.targetRIR) {
                    ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
                }
            }
            .glassRows()

            Section {
                TextField("Примітка", text: $planned.note, axis: .vertical)
            } footer: {
                Text("RIR - скільки повторів ти ще міг би зробити. 1-2 - оптимально для росту м'язів без зайвої втоми.")
            }
            .glassRows()

            Section("Замінити вправу") {
                ForEach(alternatives) { alternative in
                    Button {
                        replace(with: alternative)
                    } label: {
                        ExerciseRow(exercise: alternative)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showLibrary = true
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "books.vertical", tint: Theme.Palette.accent)
                        Text("Обрати з бібліотеки").foregroundStyle(.primary)
                    }
                }
            }
            .glassRows()
        }
        .zalScreen()
        .navigationTitle(exercise?.nameUk ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
        .sheet(isPresented: $showLibrary) {
            NavigationStack {
                ExerciseLibraryView { picked in
                    replace(with: picked)
                    showLibrary = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Скасувати") { showLibrary = false }
                    }
                }
            }
        }
    }

    /// Keeps repMin ≤ repMax while editing.
    private var repMin: Binding<Int> {
        Binding(get: { planned.repMin }, set: { value in
            planned.repMin = value
            planned.repMax = max(planned.repMax, value)
        })
    }

    private var repMax: Binding<Int> {
        Binding(get: { planned.repMax }, set: { value in
            planned.repMax = value
            planned.repMin = min(planned.repMin, value)
        })
    }

    private func replace(with exercise: Exercise) {
        planned.exerciseSlug = exercise.slug
        planned.progressionRaw = exercise.progressionRaw
        try? context.save()
        Haptics.selection()
    }
}

/// Current load in big light digits: "4 × 6-8", rest and RIR.
private struct LoadSummary: View {
    let planned: PlannedExercise

    private var reps: String {
        planned.repMin == planned.repMax ? "\(planned.repMin)" : "\(planned.repMin)-\(planned.repMax)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.l) {
            MetricText("\(planned.sets) × \(reps)", unit: planned.progression == .timed ? LocalizedStringKey("с") : nil, size: 34)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(RestFormat.text(planned.restSeconds))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text("RIR \(planned.targetRIR)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
