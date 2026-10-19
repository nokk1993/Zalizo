import ShahCore
import SwiftUI
import WidgetKit

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let snapshot = entry.snapshot
        Group {
            switch family {
            case .systemMedium: MediumView(snapshot: snapshot)
            case .accessoryCircular: CircularView(snapshot: snapshot)
            case .accessoryRectangular: RectangularView(snapshot: snapshot)
            case .accessoryInline: InlineView(snapshot: snapshot)
            default: SmallView(snapshot: snapshot)
            }
        }
        .containerBackground(Palette.surface, for: .widget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.todayAccessibility(snapshot.summary, snapshot.unit))
    }
}

private extension WidgetSnapshot {
    var summary: TodaySummary {
        TodaySummary(day: day, meters: meters, steps: steps, goalMeters: goalMeters, yesterdayMeters: nil, weekAverageMeters: nil)
    }
}

// MARK: Home Screen

private struct SmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            ProgressRing(progress: snapshot.progress, lineWidth: 14, animated: false)
                .widgetAccentable()
            VStack(spacing: 0) {
                Text(Format.distance(snapshot.meters, snapshot.unit))
                    .font(Typography.hero(34))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("з \(Format.goal(snapshot.goalMeters, snapshot.unit))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 22)
        }
    }
}

private struct MediumView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: snapshot.progress, lineWidth: 13, animated: false)
                    .widgetAccentable()
                VStack(spacing: 0) {
                    Text(Format.distance(snapshot.meters, snapshot.unit))
                        .font(Typography.hero(30))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(snapshot.unit.shortLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Сьогодні · \(DistanceFormat.percent(snapshot.progress))%")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.accentText)
                    .widgetAccentable()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                WeekBars(week: snapshot.week, goalMeters: snapshot.goalMeters)
                    .padding(.top, 8)
            }
        }
    }

    private var detail: String {
        let steps = Format.steps(snapshot.steps)
        let remaining = snapshot.goalMeters - snapshot.meters
        guard remaining > 0 else { return steps }
        return String(localized: "\(steps) · ще \(Format.distanceWithUnit(remaining, snapshot.unit))")
    }
}

private struct WeekBars: View {
    let week: [Double]
    let goalMeters: Double

    var body: some View {
        let top = max(week.max() ?? 0, goalMeters, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, meters in
                let isToday = index == week.count - 1
                Capsule()
                    .fill(isToday
                          ? AnyShapeStyle(LinearGradient(gradient: Palette.trail, startPoint: .bottom, endPoint: .top))
                          : AnyShapeStyle(Palette.accent.opacity(meters >= goalMeters ? 1 : 0.38)))
                    .frame(height: max(4, 54 * meters / top))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 54, alignment: .bottom)
        .widgetAccentable()
    }
}

// MARK: Lock Screen

private struct CircularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Gauge(value: min(max(snapshot.progress, 0), 1)) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            VStack(spacing: -2) {
                Text(Format.distance(snapshot.meters, snapshot.unit))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.5)
                Text(snapshot.unit.shortLabel)
                    .font(.system(size: 9, weight: .semibold))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

private struct RectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Шаг", systemImage: "figure.walk")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(Format.distanceWithUnit(snapshot.meters, snapshot.unit))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Gauge(value: min(max(snapshot.progress, 0), 1)) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Label("\(Format.distanceWithUnit(snapshot.meters, snapshot.unit)) · \(DistanceFormat.percent(snapshot.progress))%",
              systemImage: "figure.walk")
    }
}

// MARK: Previews

private extension TodayEntry {
    static func sample(km: Double) -> TodayEntry {
        let day = DayKey(.now, in: .current)
        var snapshot = WidgetSnapshot.placeholder(day: day, unit: .kilometers)
        snapshot.meters = km * 1000
        snapshot.week[6] = km * 1000
        return TodayEntry(date: .now, snapshot: snapshot)
    }
}

#Preview("Малий", as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry.sample(km: 7.4)
    TodayEntry.sample(km: 10.6)
}

#Preview("Середній", as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry.sample(km: 7.4)
}

#Preview("Коло", as: .accessoryCircular) {
    TodayWidget()
} timeline: {
    TodayEntry.sample(km: 7.4)
}

#Preview("Прямокутник", as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    TodayEntry.sample(km: 7.4)
}
