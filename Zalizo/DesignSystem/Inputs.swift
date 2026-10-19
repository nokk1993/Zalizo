import SwiftUI

/// Large tappable glass card for single/multiple choice (onboarding, settings).
struct OptionCard: View {
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                if let systemImage {
                    IconBadge(systemImage: systemImage, tint: isSelected ? Theme.Palette.accent : .secondary, size: 42)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(isSelected ? 0 : 0.25), lineWidth: 1.5)
                    if isSelected {
                        Circle().fill(Theme.Palette.accent)
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.Palette.onAccent)
                    }
                }
                .frame(width: 26, height: 26)
                .shadow(color: Theme.Palette.accent.opacity(isSelected ? 0.6 : 0), radius: 8)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, minHeight: Theme.largeTapTarget, alignment: .leading)
            .background { GlassSurface(cornerRadius: Theme.Radius.card, tint: isSelected ? Theme.Palette.accent : nil) }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Palette.accent.opacity(0.9) : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.card))
            .animation(.snappy(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Capsule toggle used in flow layouts and pill pickers (weekdays, food exclusions, periods).
struct ChipToggle: View {
    let title: LocalizedStringResource
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, Theme.Spacing.l)
                .frame(minHeight: 44)
                .foregroundStyle(isOn ? Theme.Palette.onAccent : Color.primary)
                .background(isOn ? Theme.Palette.accent : Theme.Palette.row, in: Capsule())
                .overlay { Capsule().strokeBorder(Color.white.opacity(isOn ? 0 : 0.12), lineWidth: 1) }
                .shadow(color: Theme.Palette.accent.opacity(isOn ? 0.35 : 0), radius: 10)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

/// Wrapping horizontal container for chips.
struct FlowLayout<Content: View>: View {
    var spacing: CGFloat = Theme.Spacing.s
    @ViewBuilder var content: Content

    var body: some View {
        FlowLayoutEngine(spacing: spacing).callAsFunction { content }
    }
}

struct FlowLayoutEngine: Layout {
    var spacing: CGFloat = Theme.Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Body-weight wheel: whole kilograms + tenths.
struct WeightWheel: View {
    @Binding var weightKg: Double
    var range: ClosedRange<Int> = 35...200

    private var whole: Binding<Int> {
        Binding(
            get: { min(max(Int(weightKg), range.lowerBound), range.upperBound) },
            set: { weightKg = Double($0) + Double(tenths.wrappedValue) / 10 }
        )
    }

    private var tenths: Binding<Int> {
        Binding(
            get: { Int(((weightKg - weightKg.rounded(.down)) * 10).rounded()) % 10 },
            set: { weightKg = Double(Int(weightKg)) + Double($0) / 10 }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Кілограми", selection: whole) {
                ForEach(Array(range), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            Text(",").font(.title2)
            Picker("Десяті", selection: tenths) {
                ForEach(0..<10, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)
            Text("кг").foregroundStyle(.secondary).padding(.leading, Theme.Spacing.s)
        }
        .frame(height: 150)
        .accessibilityElement(children: .contain)
    }
}

/// Height wheel in centimetres.
struct HeightWheel: View {
    @Binding var heightCm: Double

    private var value: Binding<Int> {
        Binding(get: { Int(heightCm.rounded()) }, set: { heightCm = Double($0) })
    }

    var body: some View {
        HStack {
            Picker("Зріст", selection: value) {
                ForEach(130...230, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            Text("см").foregroundStyle(.secondary)
        }
        .frame(height: 150)
    }
}

/// Compact weight input: text field with decimal pad + round -/+ buttons.
struct WeightField: View {
    @Binding var weightKg: Double
    var step: Double = 2.5

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button {
                weightKg = max(0, weightKg - step)
            } label: {
                CircleIcon(systemImage: "minus", size: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Зменшити вагу")

            TextField("кг", value: $weightKg, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
                .frame(width: 64)
                .padding(.vertical, 6)
                .background(Theme.Palette.row, in: .rect(cornerRadius: 10))

            Button {
                weightKg += step
            } label: {
                CircleIcon(systemImage: "plus", size: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Збільшити вагу")
        }
    }
}

extension Double {
    /// "72,5" - up to one decimal, locale-aware.
    var kgText: String { formatted(.number.precision(.fractionLength(0...1))) }
    /// "72,25" - up to two decimals (plates, rounding results).
    var preciseText: String { formatted(.number.precision(.fractionLength(0...2))) }
}

extension Int {
    /// "2 740" with locale grouping.
    var groupedText: String { formatted(.number) }
}
