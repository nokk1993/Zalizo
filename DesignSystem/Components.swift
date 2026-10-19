import ShahCore
import SwiftUI

/// Big rounded number with a small unit next to it: «7,4 км».
struct BigNumber: View {
    let meters: Double
    let unit: DistanceUnit
    var size: CGFloat = 76

    var body: some View {
        let value = DistanceFormat.rounded(meters: meters, unit: unit)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Format.distance(meters, unit))
                .font(Typography.hero(size))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(unit.shortLabel)
                .font(.system(size: size * 0.37, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
        }
        .foregroundStyle(Palette.textPrimary)
    }
}

/// Small card: label, value, caption.
struct StatCard: View {
    let title: String
    let value: String
    var caption: String?
    var valueColor: Color = Palette.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.cardLabel)
                .textCase(.uppercase)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(Typography.cardValue)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Explains why there is nothing to show and offers a way out.
struct EmptyStateView<Actions: View>: View {
    let title: LocalizedStringKey
    let message: Text
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 18) {
            ProgressRing(progress: 0, lineWidth: 16, animated: false)
                .frame(width: 140)
                .padding(.bottom, 6)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Palette.textPrimary)
            message
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 6) {
                actions
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

/// Segmented week / month / year switch.
struct PeriodPicker: View {
    @Binding var period: HistoryPeriod

    var body: some View {
        Picker("Період", selection: $period) {
            ForEach(HistoryPeriod.allCases, id: \.self) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("history.period")
    }
}

extension HistoryPeriod {
    var title: LocalizedStringKey {
        switch self {
        case .week: "Тиждень"
        case .month: "Місяць"
        case .year: "Рік"
        }
    }
}

/// A capsule with a glass look on iOS 26 and a plain surface before.
struct Pill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let label = HStack(spacing: 8) { content }
            .font(Typography.pill)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        if #available(iOS 26, *) {
            label.glassEffect(.regular, in: .capsule)
        } else {
            label.background(Palette.surface, in: .capsule)
        }
    }
}

extension View {
    /// Main call to action: Liquid Glass on iOS 26, bordered prominent before.
    @ViewBuilder
    func primaryActionStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
        } else {
            self.buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
        }
    }
}

#Preview("Компоненти") {
    VStack(spacing: 16) {
        BigNumber(meters: 7_400, unit: .kilometers)
        HStack {
            StatCard(title: "Учора · 6,2 км", value: "+1,2 км", caption: "більше, ніж учора", valueColor: Palette.positive)
            StatCard(title: "Зазвичай · 8,2 км", value: "−0,8 км", caption: "менше, ніж зазвичай")
        }
        Pill { Image(systemName: "figure.walk"); Text(verbatim: "10 482 кроки") }
    }
    .padding()
    .background(Palette.background)
}
