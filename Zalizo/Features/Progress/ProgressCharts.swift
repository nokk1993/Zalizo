import Charts
import SwiftUI
import ZalizoCore

/// Colors of chart lines, grid and labels on the dark canvas or on a white card.
private struct ChartInk {
    let grid: Color
    let label: Color
    let line: Color
    let dim: Color

    static var dark: ChartInk {
        ChartInk(grid: Color.white.opacity(0.08), label: Theme.Palette.textSecondary, line: Theme.Palette.accent, dim: Color.white.opacity(0.4))
    }

    static var light: ChartInk {
        ChartInk(grid: Color.black.opacity(0.08), label: Color.black.opacity(0.5), line: Theme.Palette.onAccent, dim: Color.black.opacity(0.35))
    }
}

private extension View {
    /// Faint grid and secondary labels on both axes.
    func progressAxes(_ ink: ChartInk, yCount: Int = 4) -> some View {
        chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(ink.grid)
                AxisValueLabel().foregroundStyle(ink.label)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: yCount)) { _ in
                AxisGridLine().foregroundStyle(ink.grid)
                AxisValueLabel().foregroundStyle(ink.label)
            }
        }
    }
}

/// Y range around the values with some air; never below zero for non-negative data.
private func paddedDomain(_ values: [Double], minimumSpan: Double = 1) -> ClosedRange<Double> {
    guard let low = values.min(), let high = values.max() else { return 0...1 }
    let pad = max((high - low) * 0.15, minimumSpan / 2)
    let lower = low >= 0 ? max(0, low - pad) : low - pad
    return lower...(high + pad)
}

/// Soft vertical glow under a line.
private func areaGradient(_ tint: Color, strength: Double = 0.35) -> LinearGradient {
    LinearGradient(colors: [tint.opacity(strength), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
}

/// Body weight: daily points (dim), 7-day average (lime with glow), target rule and dashed forecast.
struct WeightChart: View {
    let samples: [WeightSample]
    let average: [WeightSample]
    let target: Double?
    let projection: [WeightSample]
    /// Dark ink for a white card.
    var onLight = false

    private var ink: ChartInk { onLight ? .light : .dark }

    private var domain: ClosedRange<Double> {
        let values = samples.map(\.weightKg) + average.map(\.weightKg) + projection.map(\.weightKg)
        return paddedDomain(values + (target.map { [$0] } ?? []))
    }

    var body: some View {
        let baseline = domain.lowerBound
        Chart {
            ForEach(average, id: \.date) { sample in
                AreaMark(
                    x: .value("Дата", sample.date, unit: .day),
                    yStart: .value("Вага", baseline),
                    yEnd: .value("Вага", sample.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(areaGradient(Theme.Palette.accent, strength: onLight ? 0.55 : 0.35))
            }
            ForEach(samples, id: \.date) { sample in
                PointMark(x: .value("Дата", sample.date, unit: .day), y: .value("Вага", sample.weightKg))
                    .symbolSize(18)
                    .foregroundStyle(by: .value("Серія", String(localized: "Зважування")))
            }
            ForEach(average, id: \.date) { sample in
                LineMark(x: .value("Дата", sample.date, unit: .day), y: .value("Вага", sample.weightKg), series: .value("Лінія", "avg"))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(by: .value("Серія", String(localized: "Середнє за 7 днів")))
            }
            ForEach(projection, id: \.date) { sample in
                LineMark(x: .value("Дата", sample.date, unit: .day), y: .value("Вага", sample.weightKg), series: .value("Лінія", "forecast"))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 4]))
                    .foregroundStyle(by: .value("Серія", String(localized: "Прогноз")))
            }
            if let target {
                RuleMark(y: .value("Ціль", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(ink.dim)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Ціль \(target.kgText) кг")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ink.label)
                    }
            }
            if let last = average.last {
                PointMark(x: .value("Дата", last.date, unit: .day), y: .value("Вага", last.weightKg))
                    .symbol {
                        Circle()
                            .fill(Theme.Palette.accent)
                            .frame(width: 10, height: 10)
                            .overlay { Circle().strokeBorder(ink.line, lineWidth: 2) }
                            .shadow(color: Theme.Palette.accent.opacity(0.8), radius: 5)
                    }
            }
        }
        .chartForegroundStyleScale([
            String(localized: "Зважування"): ink.dim,
            String(localized: "Середнє за 7 днів"): ink.line,
            String(localized: "Прогноз"): ink.dim
        ])
        .chartYScale(domain: domain)
        .chartLegend(position: .bottom)
        .progressAxes(ink)
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
    var tint: Color = Theme.Palette.accent
    @State private var selected: Date?

    private var selectedPoint: Point? {
        guard let selected else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    var body: some View {
        let label = String(localized: valueLabel)
        let domain = paddedDomain(points.map(\.value))
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Дата", point.date, unit: .day),
                    yStart: .value(label, domain.lowerBound),
                    yEnd: .value(label, point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(areaGradient(tint))
                LineMark(x: .value("Дата", point.date, unit: .day), y: .value(label, point.value))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                PointMark(x: .value("Дата", point.date, unit: .day), y: .value(label, point.value))
                    .symbolSize(22)
                    .foregroundStyle(tint)
            }
            if let point = selectedPoint {
                RuleMark(x: .value("Дата", point.date, unit: .day))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        SelectionBubble(value: "\(point.value.kgText) \(unit)", date: point.date)
                    }
                PointMark(x: .value("Дата", point.date, unit: .day), y: .value(label, point.value))
                    .symbolSize(90)
                    .foregroundStyle(tint)
            }
        }
        .chartYScale(domain: domain)
        .chartXSelection(value: $selected)
        .progressAxes(.dark)
    }
}

/// Glass tooltip above the selected point.
private struct SelectionBubble: View {
    let value: String
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Palette.stroke, lineWidth: 1) }
    }
}

/// Workouts per week: lime when the plan is met, blue otherwise; dashed plan line.
struct WeeklyWorkoutsChart: View {
    let weeks: [StatsService.WeekCount]
    let target: Int

    var body: some View {
        Chart {
            ForEach(weeks, id: \.weekStart) { week in
                BarMark(x: .value("Тиждень", week.weekStart, unit: .weekOfYear), y: .value("Тренувань", week.count))
                    .cornerRadius(6)
                    .foregroundStyle(barStyle(count: week.count))
            }
            RuleMark(y: .value("План", target))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.white.opacity(0.4))
                .annotation(position: .top, alignment: .trailing) {
                    Text("план \(target)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
        }
        .progressAxes(.dark)
    }

    private func barStyle(count: Int) -> LinearGradient {
        let tint = count >= target ? Theme.Palette.accent : Theme.Palette.blue
        return LinearGradient(colors: [tint, tint.opacity(0.45)], startPoint: .top, endPoint: .bottom)
    }
}

/// Weekly sets per muscle group with status zones (always labelled, never colour alone).
struct MuscleVolumeChart: View {
    let weekly: [MuscleGroup: Double]

    private var rows: [(muscle: MuscleGroup, sets: Double)] {
        let groups = ProgramVolume.majorGroups + [MuscleGroup.calves, .abs]
        return groups.map { (muscle: $0, sets: weekly[$0] ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            chart
            legend
        }
    }

    private var chart: some View {
        Chart {
            RectangleMark(xStart: .value("Норма від", 10.0), xEnd: .value("Норма до", 20.0))
                .foregroundStyle(Theme.Palette.accent.opacity(0.07))
            ForEach(rows, id: \.muscle) { row in
                let zone = Volume.zone(weeklySets: row.sets)
                BarMark(
                    x: .value("Підходи", row.sets),
                    y: .value("М'яз", String(localized: row.muscle.title)),
                    height: .fixed(12)
                )
                .cornerRadius(6)
                .foregroundStyle(zone.color)
                .annotation(position: .trailing) {
                    Text("\(row.sets.kgText) · \(String(localized: zone.title))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXScale(domain: 0...max(24, (rows.map(\.sets).max() ?? 0) + 4))
        .chartXAxis {
            AxisMarks(values: .stride(by: 10)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel().foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .frame(height: CGFloat(rows.count) * 30 + 24)
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.l) {
            legendItem(.low, range: "менше 10")
            legendItem(.optimal, range: "10-20")
            legendItem(.high, range: "більше 20")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ zone: Volume.Zone, range: LocalizedStringResource) -> some View {
        HStack(spacing: 6) {
            GlowDot(color: zone.color, size: 7)
            Text("\(Text(range)) - \(Text(zone.title))")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
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
        HStack(alignment: .top, spacing: 4) {
            ForEach(0..<weeks, id: \.self) { column in
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { row in
                        let date = calendar.date(byAdding: .day, value: column * 7 + row, to: first) ?? first
                        HeatCell(
                            count: counts[Calendar.current.startOfDay(for: date)] ?? 0,
                            isFuture: date > today,
                            isToday: calendar.isDate(date, inSameDayAs: today)
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Календар тренувань: \(counts.values.reduce(0, +)) тренувань"))
    }
}

private struct HeatCell: View {
    let count: Int
    let isFuture: Bool
    let isToday: Bool

    private var fill: Color {
        if isFuture { return .clear }
        if count > 1 { return Theme.Palette.accent }
        if count == 1 { return Theme.Palette.accent.opacity(0.7) }
        return Color.white.opacity(0.06)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fill)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                }
            }
            .shadow(color: count > 0 && !isFuture ? Theme.Palette.accent.opacity(0.45) : .clear, radius: 3)
            .aspectRatio(1, contentMode: .fit)
    }
}
