import SwiftData
import SwiftUI
import ZalizoCore

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    private struct Month: Identifiable {
        let start: Date
        let sessions: [WorkoutSession]
        var id: Date { start }
    }

    /// Sessions grouped by calendar month, newest first.
    private var months: [Month] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .month, for: session.startedAt)?.start ?? calendar.startOfDay(for: session.startedAt)
        }
        return groups.keys.sorted(by: >).map { key in
            Month(start: key, sessions: groups[key] ?? [])
        }
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView("Ще немає тренувань", systemImage: "clock.arrow.circlepath")
                    .listRowBackground(Color.clear)
            }
            ForEach(months) { month in
                Section {
                    ForEach(month.sessions) { session in
                        NavigationLink {
                            WorkoutDetailView(session: session)
                        } label: {
                            HistoryRow(session: session)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { month.sessions[$0] }.forEach(context.delete)
                        try? context.save()
                    }
                } header: {
                    Text(month.start.formatted(.dateTime.month(.wide).year()))
                }
                .glassRows()
            }
        }
        .zalScreen()
        .navigationTitle("Історія тренувань")
    }
}

/// Date badge, bold title and light stats line.
private struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        let stats = WorkoutService.stats(for: session)
        HStack(spacing: Theme.Spacing.m) {
            VStack(spacing: 0) {
                Text(session.startedAt.formatted(.dateTime.day()))
                    .font(.title2.weight(.light).monospacedDigit())
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 52)
            .background(Theme.Palette.row, in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) · \(stats.durationSeconds / 60) хв · \(Int(stats.tonnage).groupedText) кг")
                    .font(.caption.weight(.light).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct WorkoutDetailView: View {
    let session: WorkoutSession

    var body: some View {
        let stats = WorkoutService.stats(for: session)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    eyebrow: Text(session.startedAt.formatted(date: .long, time: .shortened)),
                    title: Text("Тренування"),
                    accent: Text(session.title)
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible())], spacing: Theme.Spacing.s) {
                    StatTile(title: "Тривалість", value: "\(stats.durationSeconds / 60)", unit: "хв", systemImage: "stopwatch", tint: Theme.Palette.blue)
                    StatTile(title: "Тоннаж", value: Int(stats.tonnage).groupedText, unit: "кг", systemImage: "scalemass")
                    StatTile(title: "Робочих підходів", value: "\(stats.workingSets)", systemImage: "checkmark.circle")
                    if let feeling = session.feeling {
                        StatTile(title: "Самопочуття", value: String(localized: FeelingText.title(feeling)), systemImage: "heart", tint: Theme.Palette.blue)
                    }
                }

                if session.isDeload || !session.note.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        if session.isDeload {
                            Label("Розвантажувальне тренування", systemImage: "leaf")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.Palette.accent)
                        }
                        if !session.note.isEmpty {
                            Text(session.note)
                                .font(.subheadline)
                        }
                    }
                    .cardStyle()
                }

                ForEach(session.orderedExercises.filter { !$0.workingSets.isEmpty }) { performed in
                    PerformedExerciseCard(performed: performed)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .zalScreen()
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One exercise of a finished workout: name and its working sets.
private struct PerformedExerciseCard: View {
    let performed: PerformedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(performed.exerciseName).font(.headline)
            ForEach(Array(performed.workingSets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("Підхід \(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(set.weightKg.preciseText) кг × \(set.reps)\(set.rir.map { " · RIR \($0)" } ?? "")")
                        .font(.body.weight(.light).monospacedDigit())
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle(inset: Theme.Spacing.xl)
    }
}
