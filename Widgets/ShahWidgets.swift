import SwiftUI
import WidgetKit

@main
struct ShahWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

/// One widget, five sizes: Home Screen small/medium, Lock Screen circular,
/// rectangular and inline.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodayProvider.kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Сьогодні")
        .description("Скільки ти пройшов сьогодні.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
