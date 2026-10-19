import Charts
import SwiftUI
import ZalizoCore

/// Body weight: daily points (neutral), 7-day average (accent), target rule and dashed forecast.
struct WeightChart: View {
    let samples: [WeightSample]
    let average: [WeightSample]
    let target: Double?
    let projection: [WeightSample]

    var body: some View {
        Chart {
            ForEach(samples, id: \.date) { sample in
                PointMark(x: .value("Дата", sample.date, unit: .day), y: .value("Вага", sample.weightKg))
                    .symbolSize(30)
                    .foregroundStyle(by: .value("Серія", String(localized: "Зважування")))
            }
            ForEach(average, id: \.date) { sample in
                LineMark(x: .value("Дата", sample.date, unit: .day), y: .value("Вага", sample.weightKg), series: .value("Лінія", "avg"))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(by: .value("Серія", String(localized: "Середнє за 7 днів")))
            }
            ForEach(projection, id: \.date) { sample in
                LineMark(x: .value("Дата", sample.date, unit: .day), y: .value("Вага", sample.weightKg), series: .value("Лінія", "forecast"))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .foregroundStyle(by: .value("Серія", String(localized: "Прогноз")))
            }
            if let target {
                RuleMark(y: .value("Ціль", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(Color.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Ціль \(target.kgText) кг").font(.caption2).foregroundStyle(.secondary)
                    }
            }
        }
        .chartForegroundStyleScale([
            String(localized: "Зважування"): Color.secondary.opacity(0.45),
            String(localized: "Середнє за 7 днів"): Color.accentColor,
            String(localized: "Прогноз"): Color.accentColor.opacity(0.5)
        ])
        .chartYScale(domain: .automatic(includesZero: false))
        .chartLegend(position: .bottom)
        .accessibilityLabel(Text("Графік ваги"))
    }
}

/// Generic single-series line over time (1RM, max weight, measurements).
struct TrendLineChart: View {
    struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    let points: [Point]
    let valueLabel: LocalizedStringResource
    var unit = "кг"
    @State private var selected: Date?

    private var selectedPoint: Point? {
        guard let selected else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Дата", point.date, unit: .day), y: .value(String(localized: valueLabel), point.value))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Дата", point.date, unit: .day), y: .value(String(localized: valueLabel), point.value))
                    .symbolSize(40)
            }
            if let point = selectedPoint {
                RuleMark(x: .value("Дата", point.date, unit: .day))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        VStack(spacing: 0) {
                            Text("\(point.value.kgText) \(unit)").font(.caption.bold())
                            Text(point.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(Theme.Spacing.xs)
                        .background(.background, in: .rect(cornerRadius: 6))
                    }
            }
        }
        .foregroundStyle(Color.accentColor)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXSelection(value: $selected)
    }
}

/// Workouts per week - rounded bars.
struct WeeklyWorkoutsChart: View {
    let weeks: [StatsService.WeekCount]
    let target: Int

    var body: some View {
        Chart {
            ForEach(weeks, id: \.weekStart) { week in
                BarMark(x: .value("Тиждень", week.weekStart, unit: .weekOfYear), y: .value("Тренувань", week.count))
                    .cornerRadius(4)
                    .foregroundStyle(Color.accentColor)
            }
            RuleMark(y: .value("План", target))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.secondary)
                .annotation(position: .top, alignment: .trailing) {
                    Text("план \(target)").font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }
}

/// Weekly sets per muscle group with status zones (always labelled, never colour alone).
struct MuscleVolumeChart: View {
    let weekly: [MuscleGroup: Double]

    private var rows: [(muscle: MuscleGroup, sets: Double)] {
        ProgramVolume.majorGroups.map { ($0, weekly[$0] ?? 0) }
            + [MuscleGroup.calves, .abs].map { ($0, weekly[$0] ?? 0) }
    }

    var body: some View {
        Chart {
            RectangleMark(xStart: .value("Норма від", 10.0), xEnd: .value("Норма до", 20.0))
                .foregroundStyle(Theme.Palette.success.opacity(0.08))
            ForEach(rows, id: \.muscle) { row in
                let zone = Volume.zone(weeklySets: row.sets)
                BarMark(x: .value("Підходи", row.sets), y: .value("М'яз", String(localized: row.muscle.title)))
                    .cornerRadius(4)
                    .foregroundStyle(zone.color)
                    .annotation(position: .trailing) {
                        Text("\(row.sets.kgText) · \(String(localized: zone.title))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartXScale(domain: 0...max(24, (rows.map(\.sets).max() ?? 0) + 4))
        .frame(height: CGFloat(rows.count) * 28 + 20)
    }
}

/// GitHub-style calendar of workout days (last `weeks` weeks, Monday-first rows).
struct WorkoutCalendarHeatmap: View {
    let counts: [Date: Int]
    var weeks = 18

    private var calendar: Calendar { .iso }

    var body: some View {
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let first = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: weekStart) ?? weekStart
        HStack(alignment: .top, spacing: 3) {
            ForEach(0..<weeks, id: \.self) { column in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { row in
                        let date = calendar.date(byAdding: .day, value: column * 7 + row, to: first) ?? first
                        let count = counts[Calendar.current.startOfDay(for: date)] ?? 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(date > today ? Color.clear : (count > 0 ? Color.accentColor.opacity(count > 1 ? 1 : 0.75) : Color.secondary.opacity(0.15)))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Календар тренувань: \(counts.values.reduce(0, +)) тренувань"))
    }
}
