import SwiftData
import SwiftUI
import ZalizoCore

/// One training day: exercises in order, with automatic substitutions shown.
struct ProgramDayView: View {
    @Bindable var day: ProgramDay
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @Query private var profiles: [UserProfile]
    @State private var showPicker = false

    private var profile: ProfileSnapshot {
        profiles.first.map { ProfileStore.snapshot(of: $0, currentWeightKg: nil) } ?? ProfileSnapshot()
    }

    var body: some View {
        let catalog = ProgramStore.catalog(exercises)
        List {
            Section {
                TextField("Назва дня", text: $day.name)
                    .font(.headline)
                TextField("Фокус (необов'язково)", text: $day.focus)
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(day.orderedExercises) { planned in
                    NavigationLink {
                        PlannedExerciseEditor(planned: planned)
                    } label: {
                        PlannedExerciseRow(
                            planned: planned,
                            resolution: ProgramStore.resolve(planned, catalog: catalog, profile: profile),
                            exercises: exercises
                        )
                    }
                }
                .onMove { source, destination in
                    ProgramStore.reorder(day.orderedExercises, from: source, to: destination) { $0.order = $1 }
                    try? context.save()
                }
                .onDelete { offsets in
                    let ordered = day.orderedExercises
                    for index in offsets {
                        context.delete(ordered[index])
                    }
                    try? context.save()
                }
                Button {
                    showPicker = true
                } label: {
                    Label("Додати вправу", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Вправи")
                    Spacer()
                    EditButton().font(.caption)
                }
            } footer: {
                Text("Якщо для вправи немає обладнання або вона ризикована для твоїх обмежень, програма автоматично підставить безпечнішу альтернативу.")
            }
            if let program = day.program, program.days.count > 1 {
                Section {
                    Button(role: .destructive) {
                        deleteDay(from: program)
                    } label: {
                        Label("Видалити день", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                ExerciseLibraryView { exercise in
                    add(exercise)
                    showPicker = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Скасувати") { showPicker = false }
                    }
                }
            }
        }
    }

    private func add(_ exercise: Exercise) {
        let isIsolation = exercise.mechanic == .isolation
        let planned = PlannedExercise(
            order: day.exercises.count, exerciseSlug: exercise.slug, sets: 3,
            repMin: isIsolation ? 10 : 6, repMax: isIsolation ? 15 : 10, restSeconds: isIsolation ? 75 : 150
        )
        planned.progressionRaw = exercise.progressionRaw
        day.exercises.append(planned)
        try? context.save()
    }

    private func deleteDay(from program: Program) {
        let dayID = day.id
        let remaining = program.orderedDays.filter { $0.id != dayID }
        dismiss()
        context.delete(day)
        for (index, item) in remaining.enumerated() {
            item.order = index
        }
        try? context.save()
    }
}

struct PlannedExerciseRow: View {
    let planned: PlannedExercise
    let resolution: ExerciseSubstitution.Resolution
    let exercises: [Exercise]

    private func exercise(_ slug: String) -> Exercise? {
        exercises.first { $0.slug == slug }
    }

    var body: some View {
        let shown = exercise(resolution.slug)
        HStack(spacing: Theme.Spacing.m) {
            if let shown {
                ExerciseImage(exercise: shown)
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(shown?.nameUk ?? planned.exerciseSlug).font(.body.weight(.medium))
                Text(planned.prescription).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if let reason = resolution.replacedBecause {
                    if resolution.isFallback {
                        Label("Немає безпечної заміни (\(reason.text)) - будь обережний", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.danger)
                    } else {
                        Label("Замість «\(exercise(planned.exerciseSlug)?.nameUk ?? planned.exerciseSlug)»: \(reason.text)", systemImage: "arrow.triangle.swap")
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.warning)
                    }
                }
                if !planned.note.isEmpty {
                    Text(planned.note).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension PlannedExercise {
    /// "4 × 6-8 · відпочинок 3 хв · RIR 1-2"
    var prescription: String {
        let reps = repMin == repMax ? "\(repMin)" : "\(repMin)-\(repMax)"
        let unit = progression == .timed ? String(localized: "с") : ""
        return String(localized: "\(sets) × \(reps)\(unit) · відпочинок \(RestFormat.text(restSeconds)) · RIR \(targetRIR)")
    }
}

enum RestFormat {
    /// 150 → "2,5 хв", 60 → "1 хв", 45 → "45 с"
    static func text(_ seconds: Int) -> String {
        if seconds < 60 || seconds % 30 != 0 {
            return String(localized: "\(seconds) с")
        }
        let minutes = Double(seconds) / 60
        return String(localized: "\(minutes.kgText) хв")
    }
}
