import ShahCore
import SwiftUI
import WidgetKit

@main
struct ShahWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Phase 2 skeleton: reads the snapshot the app writes into the App Group.
/// Phase 6 adds direct HealthKit reads, the ring and all four families.
struct TodayProvider: TimelineProvider {
    private let store = JSONFileStore<WidgetSnapshot>(url: SharedContainer.widgetSnapshotURL)

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .placeholder(day: DayKey(.now, in: .current), unit: .preferred(for: .current)))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        // A second entry at midnight resets "today" even if nothing reloads us.
        let midnight = DayClock.nextDayStart(after: now, in: .current)
        let timeline = Timeline(
            entries: [entry(at: now), entry(at: midnight)],
            policy: .after(min(midnight, now.addingTimeInterval(30 * 60)))
        )
        completion(timeline)
    }

    private func entry(at date: Date) -> TodayEntry {
        let today = DayKey(date, in: .current)
        let stored = store.load() ?? WidgetSnapshot(
            day: today, meters: 0, steps: 0, goalMeters: AppSettings.defaultGoalMeters,
            unit: .preferred(for: .current), week: Array(repeating: 0, count: 7), updatedAt: date
        )
        return TodayEntry(date: date, snapshot: stored.asOf(date, in: .current))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(Palette.surface, for: .widget)
        }
        .configurationDisplayName("Сьогодні")
        .description("Скільки ти пройшов сьогодні.")
        .supportedFamilies([.systemSmall])
    }
}

struct TodayWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 2) {
            Text(DistanceFormat.number(meters: snapshot.meters, unit: snapshot.unit))
                .font(Typography.hero(40))
                .minimumScaleFactor(0.6)
            Text(snapshot.unit.shortLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
