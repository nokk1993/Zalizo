import Charts
import ShahCore
import SwiftUI

/// Bars for one period. Tap a bar to see its exact value; tap again to hide it.
struct HistoryChartView: View {
    let bars: [ChartBar]
    let period: HistoryPeriod
    let unit: DistanceUnit
    let goalMeters: Double
    @Binding var selected: DayKey?

    var body: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Дата", Format.dayKeyDate(bar.start), unit: xUnit),
                    y: .value("Відстань", unit.value(fromMeters: bar.meters)),
                    width: .ratio(0.64)
                )
                .cornerRadius(period == .month ? 3 : 6)
                .foregroundStyle(style(for: bar))
                .accessibilityLabel(Text(accessibilityDate(bar)))
                .accessibilityValue(Text(Format.distanceWithUnit(bar.meters, unit)))
            }

            if goalMeters > 0 {
                RuleMark(y: .value("Ціль", unit.value(fromMeters: goalMeters)))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("Ціль \(Format.goal(goalMeters, unit))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 4)
                            .background(Palette.surface.opacity(0.9), in: .rect(cornerRadius: 4))
                    }
                    .accessibilityLabel(Text("Ціль"))
                    .accessibilityValue(Text(Format.goal(goalMeters, unit)))
            }

            if let bar = selectedBar {
                RuleMark(x: .value("Дата", Format.dayKeyDate(bar.start), unit: xUnit))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        Text(callout(for: bar))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.background)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Palette.textPrimary, in: .rect(cornerRadius: 8, style: .continuous))
                            .accessibilityIdentifier("history.callout")
                    }
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartXAxis { xAxis }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.track)
                AxisValueLabel().foregroundStyle(Palette.textSecondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .onTapGesture { location in
                        select(at: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .animation(.snappy, value: bars)
    }

    // MARK: Helpers

    private var xUnit: Calendar.Component { period == .year ? .month : .day }

    private var selectedBar: ChartBar? {
        guard let selected else { return nil }
        return bars.first { $0.start == selected && !$0.isFuture }
    }

    private var yMax: Double {
        let goal = unit.value(fromMeters: goalMeters)
        let top = bars.map { unit.value(fromMeters: $0.meters) }.max() ?? 0
        return max(goal * 1.2, top * 1.1, 1)
    }

    private func style(for bar: ChartBar) -> AnyShapeStyle {
        if bar.start == selected {
            return AnyShapeStyle(LinearGradient(gradient: Palette.trail, startPoint: .bottom, endPoint: .top))
        }
        if bar.goalMet {
            return AnyShapeStyle(Palette.accent)
        }
        return AnyShapeStyle(Palette.accent.opacity(0.38))
    }

    private var xAxis: some AxisContent {
        AxisMarks(values: .stride(by: xUnit, count: period == .month ? 5 : 1)) { value in
            AxisValueLabel(centered: true) {
                if let date = value.as(Date.self) {
                    Text(axisLabel(date))
                }
            }
            .foregroundStyle(Palette.textSecondary)
        }
    }

    private func axisLabel(_ date: Date) -> String {
        switch period {
        case .week: date.formatted(.dateTime.weekday(.abbreviated))
        case .month: date.formatted(.dateTime.day())
        case .year: date.formatted(.dateTime.month(.narrow))
        }
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        let day = DayKey(date, in: .current)
        let key = period == .year ? DayKey(year: day.year, month: day.month, day: 1) : day
        guard bars.contains(where: { $0.start == key && !$0.isFuture }) else {
            selected = nil
            return
        }
        selected = selected == key ? nil : key
    }

    /// «сб, 17 жовт. · 12,63 км» — two decimals, to compare with the Health app.
    private func callout(for bar: ChartBar) -> String {
        let date = Format.dayKeyDate(bar.start)
        if period == .year {
            let month = date.formatted(.dateTime.month(.wide))
            return String(localized: "\(month) · \(Format.distanceWithUnit(bar.meters, unit, digits: 2)) за день")
        }
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(day) · \(Format.distanceWithUnit(bar.meters, unit, digits: 2))"
    }

    private func accessibilityDate(_ bar: ChartBar) -> String {
        let date = Format.dayKeyDate(bar.start)
        return period == .year
            ? date.formatted(.dateTime.month(.wide).year())
            : date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
