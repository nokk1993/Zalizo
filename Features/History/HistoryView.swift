import ShahCore
import SwiftUI

/// Week / month / year bars with the goal line, period totals and the streak.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var period: HistoryPeriod = .week
    /// 0 = the period containing today, -1 = the one before, …
    @State private var offset = 0
    @State private var selected: DayKey?

    private var firstWeekday: Int { Calendar.current.firstWeekday }

    private var window: PeriodWindow {
        PeriodWindow.containing(model.today, period: period, firstWeekday: firstWeekday)
            .shifted(by: offset, firstWeekday: firstWeekday)
    }

    var body: some View {
        let current = window
        let history = model.history
        let summary = HistoryChart.summary(for: current, history: history, today: model.today)
        let bars = HistoryChart.bars(for: current, history: history, today: model.today, goalMeters: model.settings.goalMeters)

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PeriodPicker(period: $period)
                    chartCard(window: current, summary: summary, bars: bars)
                    SummaryCards(summary: summary, period: period, unit: model.unit)
                    StreakCard(streak: model.streak)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle("Історія")
            .refreshable { await model.refresh() }
        }
        .onChange(of: period) {
            offset = 0
            selected = nil
        }
        .onChange(of: offset) { selected = nil }
    }

    private func chartCard(window: PeriodWindow, summary: PeriodSummary, bars: [ChartBar]) -> some View {
        let canGoBack = window.start > (model.history.firstDataDay ?? model.today)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: window))
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityIdentifier("history.periodTitle")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Format.distance(summary.totalMeters, model.unit))
                            .font(Typography.hero(30))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: summary.totalMeters))
                        Text(model.unit.shortLabel)
                            .font(.headline)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityElement(children: .combine)
                }
                Spacer()
                HStack(spacing: 4) {
                    StepButton(systemImage: "chevron.left", label: "Попередній період", enabled: canGoBack) { offset -= 1 }
                    StepButton(systemImage: "chevron.right", label: "Наступний період", enabled: offset < 0) { offset += 1 }
                }
            }
            HistoryChartView(bars: bars, period: period, unit: model.unit, goalMeters: model.settings.goalMeters, selected: $selected)
                .frame(height: 220)
        }
        .padding(16)
        .background(Palette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: window)
    }

    private func title(for window: PeriodWindow) -> String {
        let start = Format.dayKeyDate(window.start)
        let end = Format.dayKeyDate(window.end)
        switch window.period {
        case .week:
            let style: Date.IntervalFormatStyle = window.start.year == model.today.year && window.end.year == model.today.year
                ? .interval.day().month(.wide)
                : .interval.day().month(.wide).year()
            return (start..<end).formatted(style)
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        case .year:
            return start.formatted(.dateTime.year())
        }
    }
}

private struct StepButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(Palette.track.opacity(enabled ? 1 : 0.5), in: .circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Palette.textPrimary : Palette.textSecondary.opacity(0.5))
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }
}

private struct SummaryCards: View {
    let summary: PeriodSummary
    let period: HistoryPeriod
    let unit: DistanceUnit

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        layout {
            StatCard(title: String(localized: "Сума"),
                     value: Format.distance(summary.totalMeters, unit),
                     caption: String(localized: unit.shortLabel))
            StatCard(title: String(localized: "Середнє"),
                     value: summary.averageMeters.map { Format.distance($0, unit) } ?? "—",
                     caption: String(localized: "\(String(localized: unit.shortLabel)) / день"))
            StatCard(title: String(localized: "Найкращий"),
                     value: summary.bestDay.map { Format.distance($0.meters, unit) } ?? "—",
                     caption: summary.bestDay.map {
                         Format.dayKeyDate($0.day).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                     } ?? String(localized: unit.shortLabel))
        }
    }
}

private struct StreakCard: View {
    let streak: Streak

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(LinearGradient(gradient: Palette.trail, startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: .rect(cornerRadius: 14, style: .continuous))
                .opacity(streak.current > 0 ? 1 : 0.4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.current > 0 ? Format.streakCurrent(streak.current) : String(localized: "Серії поки немає"))
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Palette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.streak")
    }

    private var caption: String {
        switch (streak.current, streak.best) {
        case (0, 0): String(localized: "Виконай ціль, щоб почати серію")
        case (0, let best): String(localized: "Виконай ціль сьогодні · \(Format.streakBest(best))")
        case (_, let best) where !streak.includesToday: String(localized: "Сьогодні ще не виконано · \(Format.streakBest(best))")
        case (_, let best): Format.streakBest(best)
        }
    }
}

#Preview("Історія") {
    PreviewHost { HistoryView() }
}

#Preview("Історія — темна") {
    PreviewHost { HistoryView() }
        .preferredColorScheme(.dark)
}

#Preview("Історія — великий шрифт") {
    PreviewHost { HistoryView() }
        .dynamicTypeSize(.accessibility2)
}

#Preview("Історія — немає даних") {
    PreviewHost(model: .preview(days: 0)) { HistoryView() }
}
