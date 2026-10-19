import Foundation
import ShahCore
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Builds the widget timeline without opening the app.
///
/// 1. While the iPhone is unlocked, reads the last 7 days straight from
///    HealthKit (same de-duplicated statistics query as the app).
/// 2. While locked, Health data is encrypted: falls back to the snapshot the
///    app last wrote into the App Group (kept fresh by background delivery).
/// 3. Adds an entry at midnight so "today" resets to zero on time.
struct TodayProvider: TimelineProvider {
    static let kind = "TodayWidget"
    private static let refreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .placeholder(day: DayKey(.now, in: .current), unit: .preferred(for: .current)))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        nonisolated(unsafe) let completion = completion
        Task {
            let snapshot = await WidgetData.current(at: .now)
            completion(TodayEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        nonisolated(unsafe) let completion = completion
        Task {
            let now = Date.now
            let snapshot = await WidgetData.current(at: now)
            let midnight = DayClock.nextDayStart(after: now, in: .current)
            let entries = [
                TodayEntry(date: now, snapshot: snapshot),
                TodayEntry(date: midnight, snapshot: snapshot.asOf(midnight, in: .current)),
            ]
            let next = min(midnight, now.addingTimeInterval(Self.refreshInterval))
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }
}

enum WidgetData {
    private static var store: JSONFileStore<WidgetSnapshot> {
        JSONFileStore(url: SharedContainer.widgetSnapshotURL)
    }

    static func current(at date: Date) async -> WidgetSnapshot {
        let zone = TimeZone.current
        let today = DayKey(date, in: zone)
        let settings = SettingsStore(defaults: SharedContainer.defaults).load()
        let unit = settings.unit(for: .current)

        #if canImport(HealthKit)
        let health = HealthKitService()
        if health.isHealthDataAvailable,
           let totals = try? await health.dailyTotals(from: today.advanced(by: -6), through: today, timeZone: zone) {
            let history = History(totals: Dictionary(totals.map { ($0.day, $0) }, uniquingKeysWith: { $1 }),
                                  timeZoneID: zone.identifier, updatedAt: date)
            let fresh = WidgetSnapshot.make(history: history, today: today, settings: settings, unit: unit, now: date)
            // An empty answer can also mean "locked" on some iOS versions;
            // never replace real numbers with zeros.
            let cached = store.load()?.asOf(date, in: zone)
            if fresh.meters > 0 || fresh.steps > 0 || cached == nil || cached?.meters == 0 {
                try? store.save(fresh)
                return fresh
            }
        }
        #endif

        guard var cached = store.load() else {
            return WidgetSnapshot(day: today, meters: 0, steps: 0, goalMeters: settings.goalMeters, unit: unit,
                                  week: Array(repeating: 0, count: 7), updatedAt: date)
        }
        // Settings may have changed since the app wrote the snapshot.
        cached.goalMeters = settings.goalMeters
        cached.unit = unit
        return cached.asOf(date, in: zone)
    }
}
