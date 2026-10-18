import SwiftUI

/// Big number + caption tile (calories, tonnage, streaks…).
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    var unit: LocalizedStringKey?
    var systemImage: String?
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label {
                Text(title)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                if let unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// Section header with optional trailing action.
struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            trailing
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// Large +/− stepper for workout input: one-hand friendly.
struct BigStepper: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let step: Double
    var range: ClosedRange<Double> = 0...1000
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...2))

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            stepButton(systemImage: "minus", delta: -step)
            VStack(spacing: 0) {
                Text(value, format: format)
                    .font(.title.bold().monospacedDigit())
                    .contentTransition(.numericText(value: value))
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            .frame(minWidth: 72)
            stepButton(systemImage: "plus", delta: step)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value, format: format))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: step)
            case .decrement: change(by: -step)
            @unknown default: break
            }
        }
    }

    private func stepButton(systemImage: String, delta: Double) -> some View {
        Button {
            change(by: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.bold())
                .frame(width: Theme.largeTapTarget, height: Theme.largeTapTarget)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    private func change(by delta: Double) {
        withAnimation(.snappy) {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        }
    }
}

#Preview {
    @Previewable @State var weight = 72.5
    VStack(spacing: 16) {
        StatTile(title: "Калорії", value: "2 850", unit: "ккал", systemImage: "flame.fill")
        SectionHeader("Сьогодні")
        BigStepper(title: "кг", value: $weight, step: 2.5)
    }
    .padding()
}
