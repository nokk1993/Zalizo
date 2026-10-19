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
        let planned = snapshot?.sessionsPerWeek ?? 3
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    PillPicker(selection: $period, options: StatsPeriod.allCases) { $0.title }

                    // The link wraps the card so the card's light environment doesn't leak into the pushed screen.
                    NavigationLink {
                        BodyWeightView()
                    } label: {
                        WeightHeadlineCard(entries: weights, snapshot: snapshot, period: period)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Усі зважування"))

                    if records.isEmpty {
                        EmptyProgressCard()
                    } else {
                        StatsGrid(overview: StatsService.overview(records, period: period))
                        AttendanceCard(dates: records.map(\.date), planned: planned)
                        WeeklyWorkoutsCard(dates: records.map(\.date), planned: planned)
                        MuscleVolumeCard(weekly: StatsService.weeklyMuscleSets(records))
                    }

                    DetailLinks()
                }
                .padding(Theme.Spacing.l)
            }
            .zalScreen()
            .navigationTitle("Прогрес")
        }
    }
}

// MARK: - Dashboard cards

/// White headline card: current 7-day average, pace and the weight chart. Opens all weigh-ins.
private struct WeightHeadlineCard: View {
    let entries: [BodyWeightEntry]
    let snapshot: ProfileSnapshot?
    let period: StatsPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Вага тіла").eyebrow()
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.07), in: Circle())
                    .accessibilityHidden(true)
            }
            WeightSummary(entries: entries, snapshot: snapshot, period: period, onLight: true)
        }
        .lightCardStyle()
        .contentShape(.rect(cornerRadius: Theme.Radius.hero))
    }
}

private struct EmptyProgressCard: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            IconBadge(systemImage: "chart.line.uptrend.xyaxis", tint: Theme.Palette.accent, size: 56)
            Text("Ще немає тренувань").font(.title3.weight(.semibold))
            Text("Заверши перше тренування - тут з'являться графіки сили, об'єму і рекорди.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(inset: Theme.Spacing.xl)
    }
}

private struct StatsGrid: View {
    let overview: StatsService.Overview

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible())], spacing: Theme.Spacing.s) {
            StatTile(title: "Тренувань", value: "\(overview.workouts)", systemImage: "figure.strengthtraining.traditional")
            StatTile(title: "На тиждень", value: overview.workoutsPerWeek.kgText, systemImage: "calendar", tint: Theme.Palette.blue)
            StatTile(title: "Середня тривалість", value: "\(overview.averageDurationMinutes)", unit: "хв", systemImage: "stopwatch", tint: Theme.Palette.blue)
            StatTile(title: "Тоннаж", value: (overview.totalTonnage / 1000).kgText, unit: "т", systemImage: "scalemass")
        }
    }
}

/// Streak in big thin digits above the visit heatmap.
private struct AttendanceCard: View {
    let dates: [Date]
    let planned: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Відвідування").eyebrow()
                    MetricText("\(TrainingSchedule.weekStreak(workoutDates: dates, target: planned))", unit: "тижн. поспіль", size: 40)
                }
                Spacer(minLength: 0)
                IconBadge(systemImage: "flame.fill", tint: Theme.Palette.accent)
            }
            WorkoutCalendarHeatmap(counts: StatsService.dailyCounts(dates))
            HStack(spacing: 6) {
                GlowDot(size: 6)
                Text("Серія з планом \(planned) трен. на тиждень")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle(inset: Theme.Spacing.xl)
    }
}

private struct WeeklyWorkoutsCard: View {
    let dates: [Date]
    let planned: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Тренувань на тиждень").eyebrow()
            WeeklyWorkoutsChart(weeks: StatsService.workoutsPerWeek(dates, weeks: 12), target: planned)
                .frame(height: 170)
        }
        .cardStyle(inset: Theme.Spacing.xl)
    }
}

private struct MuscleVolumeCard: View {
    let weekly: [MuscleGroup: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Об'єм цього тижня").eyebrow()
                Text("Робочі підходи на групу м'язів")
                    .font(.title3.weight(.light))
            }
            MuscleVolumeChart(weekly: weekly)
            BodyMapView(intensities: weekly.mapValues { $0 / 20 })
                .frame(height: 200)
        }
        .cardStyle(inset: Theme.Spacing.xl)
    }
}

/// Glass navigation rows to the detailed screens.
private struct DetailLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader("Детально")
            NavigationLink {
                ExerciseProgressListView()
            } label: {
                DetailRow(systemImage: "trophy", title: "Сила по вправах і рекорди", subtitle: "1ПМ, макс. вага, тоннаж")
            }
            NavigationLink {
                MeasurementsView()
            } label: {
                DetailRow(systemImage: "ruler", title: "Заміри тіла", subtitle: "Груди, талія, руки та інше")
            }
            NavigationLink {
                ProgressPhotosView()
            } label: {
                DetailRow(systemImage: "photo.on.rectangle", title: "Фото прогресу", subtitle: "До і після")
            }
            NavigationLink {
                WorkoutHistoryView()
            } label: {
                DetailRow(systemImage: "clock.arrow.circlepath", title: "Історія тренувань", subtitle: "Усі тренування по днях")
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DetailRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconBadge(systemImage: systemImage, tint: Theme.Palette.accent, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .cardStyle(inset: Theme.Spacing.m)
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Weight summary

/// Weight: 7-day average in big thin digits, pace, chart with moving average, goal and forecast.
struct WeightSummary: View {
    let entries: [BodyWeightEntry]
    let snapshot: ProfileSnapshot?
    let period: StatsPeriod
    /// Dark ink for a white card.
    var onLight = false

    var body: some View {
        let all = StatsStore.weightSamples(entries)
        let samples = all.filter { period.contains($0.date) }
        let average = WeightTrend.movingAverage(samples)
        let summary = snapshot.map { PlanCalculator.summary(for: $0) }
        let weekly = WeightTrend.weeklyChangeKg(all)
        if samples.isEmpty {
            Text("Додай зважування - тут з'явиться графік ваги з ковзним середнім і прогнозом.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                WeightHeadline(current: average.last?.weightKg, weekly: weekly, onLight: onLight)
                WeightChart(
                    samples: samples,
                    average: average,
                    target: summary?.targetWeightKg,
                    projection: projection(from: average, summary: summary),
                    onLight: onLight
                )
                .frame(height: 200)
                if let summary, let current = average.last?.weightKg, let weekly, summary.kgPerWeek > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        GlowDot(color: onLight ? Theme.Palette.accentDeep : Theme.Palette.accent, size: 6)
                        Text(paceVerdict(percent: weekly / current * 100, range: summary.recommendedRatePercent))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func projection(from average: [WeightSample], summary: PlanSummary?) -> [WeightSample] {
        guard let last = average.last, let summary, summary.kgPerWeek > 0 else { return [] }
        return WeightTrend.projection(from: last, kgPerWeek: summary.kgPerWeek, targetKg: summary.targetWeightKg)
    }
}

private struct WeightHeadline: View {
    let current: Double?
    let weekly: Double?
    let onLight: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if let current {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Середнє за 7 днів")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MetricText(current.kgText, unit: "кг", size: 52)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: Theme.Spacing.s)
            if let weekly {
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text("Темп")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(weekly >= 0 ? "+" : "")\(weekly.preciseText) кг/тижд")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(onLight ? Theme.Palette.onAccent : Theme.Palette.accent)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 6)
                        .background(onLight ? Theme.Palette.accent : Theme.Palette.accent.opacity(0.14), in: Capsule())
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private func paceVerdict(percent: Double, range: ClosedRange<Double>) -> LocalizedStringResource {
    if percent < range.lowerBound { return "Повільніше за рекомендований темп" }
    if percent > range.upperBound { return "Швидше за рекомендований темп - частина набору може бути жиром" }
    return "У рекомендованому темпі"
}

#Preview {
    ProgressDashboardView()
        .previewData()
}
