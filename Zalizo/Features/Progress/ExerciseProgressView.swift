import SwiftData
import SwiftUI
import ZalizoCore

/// Exercises with history → per-exercise charts and records.
struct ExerciseProgressListView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished }) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.nameUk) private var exercises: [Exercise]

    var body: some View {
        let done = Set(sessions.flatMap { $0.exercises.filter { !$0.workingSets.isEmpty }.map(\.exerciseSlug) })
        let list = exercises.filter { done.contains($0.slug) }
        List {
            if list.isEmpty {
                ContentUnavailableView("Ще немає даних", systemImage: "trophy", description: Text("Після тренувань тут з'являться графіки по кожній вправі."))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(list) { exercise in
                        NavigationLink {
                            ExerciseProgressView(exercise: exercise)
                        } label: {
                            ExerciseRow(exercise: exercise)
                        }
                    }
                }
                .glassRows()
            }
        }
        .zalScreen()
        .navigationTitle("Сила по вправах")
    }
}

struct ExerciseProgressView: View {
    enum Metric: String, CaseIterable {
        case oneRM, maxWeight, tonnage

        var title: LocalizedStringResource {
            switch self {
            case .oneRM: "Оцінка 1ПМ"
            case .maxWeight: "Макс. вага"
            case .tonnage: "Тоннаж"
            }
        }
    }

    let exercise: Exercise
    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]
    @Query private var exercises: [Exercise]
    @Query private var settings: [AppSettings]
    @State private var metric: Metric = .oneRM
    @State private var period: StatsPeriod = .all

    var body: some View {
        let formula = settings.first?.oneRMFormula ?? .epley
        let allRecords = StatsStore.records(sessions, exercises: exercises)
        let series = StatsService.exerciseSeries(allRecords.filter { period.contains($0.date) }, slug: exercise.slug, formula: formula)
        let repRecords = StatsService.repRecords(allRecords, slug: exercise.slug)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                PhotoCard(exercise: exercise, minHeight: 200) {
                    BestOneRMHeader(best: series.map(\.estimatedOneRM).max(), formula: formula)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    PillPicker(selection: $metric, options: Metric.allCases) { $0.title }
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        Text(metric.title).eyebrow()
                        if series.isEmpty {
                            Text("Немає даних за цей період")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            TrendLineChart(points: series.map { .init(date: $0.date, value: value($0)) }, valueLabel: metric.title)
                                .frame(height: 220)
                        }
                    }
                    .cardStyle(inset: Theme.Spacing.xl)
                    PillPicker(selection: $period, options: StatsPeriod.allCases) { $0.title }
                }

                RepRecordsGrid(records: repRecords)

                ExerciseHistoryList(exercise: exercise, sessions: sessions)
            }
            .padding(Theme.Spacing.l)
        }
        .zalScreen()
        .navigationTitle(exercise.nameUk)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func value(_ point: StatsService.ExercisePoint) -> Double {
        switch metric {
        case .oneRM: point.estimatedOneRM
        case .maxWeight: point.maxWeight
        case .tonnage: point.tonnage
        }
    }
}

/// Bottom of the photo card: best estimated 1RM in big thin digits.
private struct BestOneRMHeader: View {
    let best: Double?
    let formula: OneRMFormula

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(formula == .epley ? "Найкраща оцінка 1ПМ (Еплі)" : "Найкраща оцінка 1ПМ (Бжицкі)").eyebrow()
            if let best {
                MetricText(best.kgText, unit: "кг", size: 52)
            } else {
                Text("Ще немає даних")
                    .font(.title2.weight(.light))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Personal records by rep count as small glass tiles.
private struct RepRecordsGrid: View {
    let records: [StatsService.RepRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader("Особисті рекорди")
            if records.isEmpty {
                Text("Ще немає")
                    .foregroundStyle(.secondary)
                    .cardStyle()
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible())], spacing: Theme.Spacing.s) {
                    ForEach(records, id: \.reps) { record in
                        RecordTile(record: record)
                    }
                }
            }
        }
    }
}

private struct RecordTile: View {
    let record: StatsService.RepRecord

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: 6) {
                GlowDot(size: 6)
                Text("\(record.reps) \(record.reps == 1 ? "повтор" : "повт.")")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            MetricText(record.weight.preciseText, unit: "кг", size: 30)
            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// Sessions with this exercise: date + sets in light digits.
private struct ExerciseHistoryList: View {
    let exercise: Exercise
    let sessions: [WorkoutSession]

    private var withExercise: [WorkoutSession] {
        sessions.filter { session in
            session.exercises.contains { $0.exerciseSlug == exercise.slug && !$0.workingSets.isEmpty }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader("Історія")
            LazyVStack(spacing: Theme.Spacing.s) {
                ForEach(withExercise) { session in
                    let sets = session.exercises.filter { $0.exerciseSlug == exercise.slug }.flatMap(\.workingSets)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .omitted)).eyebrow()
                        Text(sets.map { "\($0.weightKg.preciseText)×\($0.reps)" }.joined(separator: ", "))
                            .font(.body.weight(.light).monospacedDigit())
                    }
                    .cardStyle(inset: Theme.Spacing.m + 2)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
