import ShahCore
import SwiftUI

/// Main screen: today's distance, the goal ring, steps, and how today
/// compares with yesterday and with a usual day.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 76

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Format.dayKeyDate(model.today), format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityIdentifier("today.date")
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.always)
            .refreshable { await model.refresh() }
            .background(Palette.background)
            .navigationTitle("Сьогодні")
        }
        .sensoryFeedback(.success, trigger: model.celebrationTrigger)
    }

    @ViewBuilder
    private var content: some View {
        if model.status == .healthUnavailable {
            EmptyStateView(title: "Health недоступний", message: Text("На цьому пристрої немає Apple Health, тому Шагу нема звідки брати дані.")) {}
        } else if model.hasNoData {
            NoDataView()
        } else {
            TodayDashboard(summary: model.summary, unit: model.unit, heroSize: heroSize, celebrationTrigger: model.celebrationTrigger)
                .redacted(reason: model.status == .loading ? .placeholder : [])
        }
    }
}

private struct TodayDashboard: View {
    let summary: TodaySummary
    let unit: DistanceUnit
    let heroSize: CGFloat
    let celebrationTrigger: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 22) {
            ringBlock
                .padding(.top, 20)
            Pill {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Palette.accent)
                Text(Format.steps(summary.steps))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(summary.steps)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("today.steps")
            comparisonCards
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: summary)
    }

    @ViewBuilder
    private var ringBlock: some View {
        let center = VStack(spacing: 8) {
            BigNumber(meters: summary.meters, unit: unit, size: heroSize)
            Text(Format.progressLine(summary, unit))
                .font(.callout.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
            if summary.isGoalMet {
                Label("Ціль виконано", systemImage: "checkmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LinearGradient(gradient: Palette.trail, startPoint: .leading, endPoint: .trailing), in: .capsule)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 44)

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Huge text does not fit inside the ring: stack it below.
                VStack(spacing: 16) {
                    ProgressRing(progress: summary.progress, lineWidth: 22)
                        .frame(maxWidth: 200)
                    center
                }
            } else {
                ZStack {
                    ProgressRing(progress: summary.progress, lineWidth: 30)
                    center
                }
                .frame(maxWidth: 300)
                .overlay {
                    ConfettiView(trigger: celebrationTrigger)
                        .frame(width: 420, height: 420)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.todayAccessibility(summary, unit))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("today.distance")
    }

    private var comparisonCards: some View {
        let yesterday = Format.yesterday(summary, unit)
        let usual = Format.usual(summary, unit)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            StatCard(title: yesterday.title, value: yesterday.value, caption: yesterday.caption,
                     valueColor: yesterday.isMore ? Palette.positive : Palette.textPrimary)
            StatCard(title: usual.title, value: usual.value, caption: usual.caption,
                     valueColor: usual.isMore ? Palette.positive : Palette.textPrimary)
        }
    }
}

/// Health returned nothing. HealthKit does not say whether read access was
/// denied, so explain where to check it.
private struct NoDataView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        EmptyStateView(
            title: "Немає даних",
            message: Text("Можливо, Шаг не має доступу до Health. Перевір: **Параметри → Здоров'я → Доступ до даних і пристрої → Шаг** і увімкни «Відстань ходьби та бігу» та «Кроки».")
        ) {
            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("Оновити")
                    .frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
            .accessibilityIdentifier("empty.refresh")

            Button("Відкрити «Здоров'я»") {
                if let url = URL(string: "x-apple-health://") { openURL(url) }
            }
            .foregroundStyle(Palette.accentText)
            .padding(.top, 4)
        }
        .padding(.top, 40)
    }
}

#Preview("Сьогодні") {
    PreviewHost { TodayView() }
}

#Preview("Темна тема") {
    PreviewHost { TodayView() }
        .preferredColorScheme(.dark)
}

#Preview("Ціль виконано") {
    PreviewHost(model: .preview(settings: AppSettings(goalMeters: 5_000, hasCompletedOnboarding: true))) { TodayView() }
}

#Preview("Великий шрифт") {
    PreviewHost { TodayView() }
        .dynamicTypeSize(.accessibility2)
}

#Preview("Немає даних") {
    PreviewHost(model: .preview(days: 0)) { TodayView() }
}
