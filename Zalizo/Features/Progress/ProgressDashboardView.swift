import SwiftData
import SwiftUI
import ZalizoCore

/// "Прогрес" tab.
struct ProgressDashboardView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]
    @Query private var exercises: [Exercise]
    @Query(sort: \BodyWeightEntry.date) private var weights: [BodyWeightEntry]
    @Query private var profiles: [UserProfile]
    @State private var period: StatsPeriod = .threeMonths

    private var snapshot: ProfileSnapshot? {
        profiles.first.map { ProfileStore.snapshot(of: $0, currentWeightKg: weights.last?.weightKg) }
    }

    var body: some View {
        let records = StatsStore.records(sessions, exercises: exercises)
        let overview = StatsService.overview(records, period: period)
        let dates = records.map(\.date)
        let planned = snapshot?.sessionsPerWeek ?? 3
        NavigationStack {
            List {
                Section {
                    Picker("Період", selection: $period) {
                        ForEach(StatsPeriod.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if records.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Ще немає тренувань", systemImage: "chart.line.uptrend.xyaxis")
                        } description: {
                            Text("Заверши перше тренування — тут з'являться графіки сили, об'єму і рекорди.")
                        }
                    }
                } else {
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.s) {
                            StatTile(title: "Тренувань", value: "\(overview.workouts)", systemImage: "figure.strengthtraining.traditional")
                            StatTile(title: "На тиждень", value: overview.workoutsPerWeek.kgText, systemImage: "calendar")
                            StatTile(title: "Середня тривалість", value: "\(overview.averageDurationMinutes)", unit: "хв", systemImage: "stopwatch")
                            StatTile(title: "Тоннаж", value: (overview.totalTonnage / 1000).kgText, unit: "т", systemImage: "scalemass")
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    Section {
                        WorkoutCalendarHeatmap(counts: StatsService.dailyCounts(dates))
                        Text("Серія: \(TrainingSchedule.weekStreak(workoutDates: dates, target: planned)) тижн. поспіль з планом \(planned) трен.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Відвідування")
                    }

                    Section("Тренувань на тиждень") {
                        WeeklyWorkoutsChart(weeks: StatsService.workoutsPerWeek(dates, weeks: 12), target: planned)
                            .frame(height: 160)
                    }

                    Section {
                        let weekly = StatsService.weeklyMuscleSets(records)
                        MuscleVolumeChart(weekly: weekly)
                        BodyMapView(intensities: weekly.mapValues { min($0 / 20, 1) })
                            .frame(height: 200)
                    } header: {
                        Text("Об'єм цього тижня")
                    } footer: {
                        Text("Робочі підходи на групу м'язів: менше 10 — мало, 10–20 — норма, більше 20 — багато.")
                    }
                }

                Section("Вага тіла") {
                    WeightSummary(entries: weights, snapshot: snapshot, period: period)
                    NavigationLink {
                        BodyWeightView()
                    } label: {
                        Label("Усі зважування", systemImage: "scalemass")
                    }
                }

                Section {
                    NavigationLink {
                        ExerciseProgressListView()
                    } label: {
                        Label("Сила по вправах і рекорди", systemImage: "trophy")
                    }
                    NavigationLink {
                        MeasurementsView()
                    } label: {
                        Label("Заміри тіла", systemImage: "ruler")
                    }
                    NavigationLink {
                        ProgressPhotosView()
                    } label: {
                        Label("Фото прогресу", systemImage: "photo.on.rectangle")
                    }
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Label("Історія тренувань", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationTitle("Прогрес")
        }
    }
}

/// Weight chart with moving average, goal, forecast and pace.
struct WeightSummary: View {
    let entries: [BodyWeightEntry]
    let snapshot: ProfileSnapshot?
    let period: StatsPeriod

    var body: some View {
        let samples = StatsStore.weightSamples(entries).filter { period.contains($0.date) }
        let average = WeightTrend.movingAverage(samples)
        let summary = snapshot.map { PlanCalculator.summary(for: $0) }
        let weekly = WeightTrend.weeklyChangeKg(StatsStore.weightSamples(entries))
        if samples.isEmpty {
            Text("Додай зважування — тут з'явиться графік ваги з ковзним середнім і прогнозом.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            let projection: [WeightSample] = {
                guard let last = average.last, let summary, summary.kgPerWeek > 0 else { return [] }
                return WeightTrend.projection(from: last, kgPerWeek: summary.kgPerWeek, targetKg: summary.targetWeightKg)
            }()
            WeightChart(samples: samples, average: average, target: summary?.targetWeightKg, projection: projection)
                .frame(height: 220)
            HStack {
                if let current = average.last {
                    VStack(alignment: .leading) {
                        Text("Середнє за 7 днів").font(.caption).foregroundStyle(.secondary)
                        Text("\(current.weightKg.kgText) кг").font(.headline.monospacedDigit())
                    }
                }
                Spacer()
                if let weekly {
                    VStack(alignment: .trailing) {
                        Text("Темп").font(.caption).foregroundStyle(.secondary)
                        Text("\(weekly >= 0 ? "+" : "")\(weekly.preciseText) кг/тижд").font(.headline.monospacedDigit())
                    }
                }
            }
            if let summary, let current = average.last?.weightKg, let weekly, summary.kgPerWeek > 0 {
                Text(paceVerdict(percent: weekly / current * 100, range: summary.recommendedRatePercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func paceVerdict(percent: Double, range: ClosedRange<Double>) -> LocalizedStringResource {
    if percent < range.lowerBound { return "Повільніше за рекомендований темп" }
    if percent > range.upperBound { return "Швидше за рекомендований темп — частина набору може бути жиром" }
    return "У рекомендованому темпі"
}

#Preview {
    ProgressDashboardView()
        .previewData()
}
