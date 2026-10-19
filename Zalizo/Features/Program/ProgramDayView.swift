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
                DayHero(day: day, cover: cover(catalog: catalog))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: 0, bottom: Theme.Spacing.s, trailing: 0))
            }
            Section {
                TextField("Назва дня", text: $day.name)
                    .font(.headline)
                TextField("Фокус (необов'язково)", text: $day.focus)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Назва")
            }
            .glassRows()
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
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "plus", tint: Theme.Palette.accent)
                        Text("Додати вправу").foregroundStyle(.primary)
                    }
                }
            } header: {
                SectionHeader(title: "Вправи") {
                    EditButton().font(.subheadline.weight(.semibold))
                }
                .textCase(nil)
                .foregroundStyle(.primary)
            } footer: {
                Text("Якщо для вправи немає обладнання або вона ризикована для твоїх обмежень, програма автоматично підставить безпечнішу альтернативу.")
            }
            .glassRows()
            if let program = day.program, program.days.count > 1 {
                Section {
                    Button(role: .destructive) {
                        deleteDay(from: program)
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            IconBadge(systemImage: "trash", tint: Theme.Palette.danger)
                            Text("Видалити день").foregroundStyle(Theme.Palette.danger)
                        }
                    }
                }
                .glassRows()
            }
        }
        .zalScreen()
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

    /// Photo of the first exercise actually performed (after substitutions).
    private func cover(catalog: [String: ExerciseInfo]) -> Exercise? {
        guard let first = day.orderedExercises.first else { return nil }
        let slug = ProgramStore.resolve(first, catalog: catalog, profile: profile).slug
        return exercises.first { $0.slug == slug }
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

/// Day header: monochrome photo card with the day name and totals.
private struct DayHero: View {
    let day: ProgramDay
    let cover: Exercise?

    private var totalSets: Int { day.exercises.reduce(0) { $0 + $1.sets } }

    var body: some View {
        PhotoCard(exercise: cover, minHeight: 200) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("День \(day.order + 1)").eyebrow()
                Text(day.name.isEmpty ? String(localized: "Без назви") : day.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                if !day.focus.isEmpty {
                    Text(day.focus)
                        .font(.subheadline.weight(.light))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                HStack(spacing: Theme.Spacing.l) {
                    MetricText("\(day.exercises.count)", unit: "вправ", size: 30)
                    MetricText("\(totalSets)", unit: "підходів", size: 30)
                }
                .foregroundStyle(Color.white)
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PlannedExerciseRow: View {
    let planned: PlannedExercise
    let resolution: ExerciseSubstitution.Resolution
    let exercises: [Exercise]

    private func exercise(_ slug: String) -> Exercise? {
        exercises.first { $0.slug == slug }
    }

    /// Name of the planned exercise before substitution.
    private var originalName: String {
        exercise(planned.exerciseSlug)?.nameUk ?? planned.exerciseSlug
    }

    var body: some View {
        let shown = exercise(resolution.slug)
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Group {
                if let shown {
                    ExerciseImage(exercise: shown)
                } else {
                    ZStack {
                        Theme.Palette.row
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.title3.weight(.light))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(shown?.nameUk ?? planned.exerciseSlug)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(planned.dayRowVolume)
                    .font(.title3.weight(.light).monospacedDigit())
                    .foregroundStyle(.primary)
                Text(planned.dayRowRest)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let reason = resolution.replacedBecause {
                    if resolution.isFallback {
                        SubstitutionBadge(
                            text: String(localized: "Немає безпечної заміни (\(reason.text)) - будь обережний"),
                            systemImage: "exclamationmark.triangle.fill",
                            tint: Theme.Palette.danger
                        )
                    } else {
                        SubstitutionBadge(
                            text: String(localized: "Замість «\(originalName)»: \(reason.text)"),
                            systemImage: "arrow.triangle.swap",
                            tint: Theme.Palette.warning
                        )
                    }
                }
                if !planned.note.isEmpty {
                    Text(planned.note).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Tinted rounded badge for automatic substitutions.
private struct SubstitutionBadge: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 10, style: .continuous))
        .padding(.top, 2)
    }
}

private extension PlannedExercise {
    /// "4 × 6-8"
    var dayRowVolume: String {
        let reps = repMin == repMax ? "\(repMin)" : "\(repMin)-\(repMax)"
        let unit = progression == .timed ? String(localized: " с") : ""
        return "\(sets) × \(reps)\(unit)"
    }

    /// "відпочинок 3 хв · RIR 1"
    var dayRowRest: String {
        String(localized: "відпочинок \(RestFormat.text(restSeconds)) · RIR \(targetRIR)")
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
