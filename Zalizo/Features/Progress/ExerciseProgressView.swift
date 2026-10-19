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
            }
            ForEach(list) { exercise in
                NavigationLink {
                    ExerciseProgressView(exercise: exercise)
                } label: {
                    ExerciseRow(exercise: exercise)
                }
            }
        }
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
        let records = StatsStore.records(sessions, exercises: exercises).filter { period.contains($0.date) }
        let series = StatsService.exerciseSeries(records, slug: exercise.slug, formula: formula)
        let repRecords = StatsService.repRecords(StatsStore.records(sessions, exercises: exercises), slug: exercise.slug)
        List {
            Section {
                Picker("Показник", selection: $metric) {
                    ForEach(Metric.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Період", selection: $period) {
                    ForEach(StatsPeriod.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if series.isEmpty {
                    Text("Немає даних за цей період").foregroundStyle(.secondary)
                } else {
                    TrendLineChart(points: series.map { .init(date: $0.date, value: value($0)) }, valueLabel: metric.title)
                        .frame(height: 220)
                }
                if let best = series.map(\.estimatedOneRM).max() {
                    Text("Найкраща оцінка 1ПМ: \(best.kgText) кг\(formula == .epley ? " (Еплі)" : " (Бжицкі)")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Особисті рекорди") {
                if repRecords.isEmpty {
                    Text("Ще немає").foregroundStyle(.secondary)
                }
                ForEach(repRecords, id: \.reps) { record in
                    LabeledContent {
                        VStack(alignment: .trailing) {
                            Text("\(record.weight.preciseText) кг").bold().monospacedDigit()
                            Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        }
                    } label: {
                        Text("\(record.reps) \(record.reps == 1 ? "повтор" : "повт.")")
                    }
                }
            }
            Section("Історія") {
                ForEach(sessions.filter { session in session.exercises.contains { $0.exerciseSlug == exercise.slug && !$0.workingSets.isEmpty } }) { session in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.bold())
                        let sets = session.exercises.filter { $0.exerciseSlug == exercise.slug }.flatMap(\.workingSets)
                        Text(sets.map { "\($0.weightKg.preciseText)×\($0.reps)" }.joined(separator: ", "))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
