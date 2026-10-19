import SwiftUI

/// Big thin number with a small unit ("2 850 ккал"). Scales with Dynamic Type.
struct MetricText: View {
    let value: String
    var unit: LocalizedStringKey?
    @ScaledMetric private var size: CGFloat

    init(_ value: String, unit: LocalizedStringKey? = nil, size: CGFloat = 40) {
        self.value = value
        self.unit = unit
        _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.system(size: size, weight: .thin).monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let unit {
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Glass tile with a caption and a big thin value (calories, tonnage, streaks…).
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    var unit: LocalizedStringKey?
    var systemImage: String?
    var tint: Color = Theme.Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                } else {
                    GlowDot(color: tint, size: 6)
                }
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            MetricText(value, unit: unit, size: 30)
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
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            trailing
        }
        .padding(.top, Theme.Spacing.s)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// Screen intro: small eyebrow, a light line and a bold accent line, round actions on the right.
struct ScreenHeader<Trailing: View>: View {
    var eyebrow: Text?
    let title: Text
    var accent: Text?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    eyebrow.eyebrow().padding(.bottom, Theme.Spacing.xs)
                }
                title.font(.largeTitle.weight(.light))
                if let accent {
                    accent.font(.largeTitle.weight(.bold))
                }
            }
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.s) { trailing }
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: Text? = nil, title: Text, accent: Text? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.accent = accent
        self.trailing = EmptyView()
    }
}

/// Round glass icon (use as a NavigationLink label with `.buttonStyle(.plain)`).
struct CircleIcon: View {
    let systemImage: String
    var prominent = false
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.37, weight: .semibold))
            .foregroundStyle(prominent ? Theme.Palette.onAccent : Color.primary)
            .frame(width: size, height: size)
            .glassEffect(prominent ? .regular.tint(Theme.Palette.accent).interactive() : .regular.interactive(), in: Circle())
            .contentShape(Circle())
    }
}

/// Round glass icon button (header actions, card corners).
struct CircleIconButton: View {
    let systemImage: String
    let label: LocalizedStringResource
    var prominent = false
    var size: CGFloat = 46
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemImage: systemImage, prominent: prominent, size: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Flat round icon for rows and cards.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = .primary
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.08), in: Circle())
            .overlay { Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

/// Small glowing status dot.
struct GlowDot: View {
    var color: Color = Theme.Palette.accent
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.8), radius: size * 0.75)
            .accessibilityHidden(true)
    }
}

/// Glowing progress ring, or a 270° gauge.
struct ProgressRing<Center: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.Palette.accent
    var isGauge = false
    @ViewBuilder var center: Center

    private var span: Double { isGauge ? 0.75 : 1 }
    private var rotation: Angle { .degrees(isGauge ? 135 : -90) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: span)
                .stroke(Color.white.opacity(0.09), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(rotation)
            Circle()
                .trim(from: 0, to: span * min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(rotation)
                .shadow(color: tint.opacity(0.55), radius: lineWidth * 0.8)
            center
        }
        .padding(lineWidth / 2)
        .animation(.smooth, value: progress)
    }
}

extension ProgressRing where Center == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 10, tint: Color = Theme.Palette.accent, isGauge: Bool = false) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
        self.isGauge = isGauge
        self.center = EmptyView()
    }
}

/// Big rounded card with a monochrome exercise photo fading into the canvas; content sits at the bottom.
struct PhotoCard<Content: View>: View {
    var exercise: Exercise?
    var minHeight: CGFloat = 220
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
        content
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .bottomLeading)
            .background {
                ZStack {
                    if let exercise {
                        ExerciseImage(exercise: exercise)
                    } else {
                        PhotoPlaceholder()
                    }
                    LinearGradient(
                        colors: [.clear, Theme.Palette.canvasBottom.opacity(0.4), Theme.Palette.canvasBottom.opacity(0.92)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
    }
}

/// Stand-in for a missing photo: blue-gray glow with a thin athlete symbol that fits any size.
struct PhotoPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.Palette.ice.opacity(0.35), Theme.Palette.canvasTop], startPoint: .topTrailing, endPoint: .bottomLeading)
            Image(systemName: "figure.strengthtraining.traditional")
                .resizable()
                .scaledToFit()
                .fontWeight(.thin)
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: 88, maxHeight: 88)
                .padding(Theme.Spacing.m)
        }
        .accessibilityHidden(true)
    }
}

/// Week of day pills: today is white, training days have a dot, finished ones glow lime.
struct WeekStrip: View {
    struct Day: Identifiable, Hashable {
        let date: Date
        var isTraining: Bool
        var isDone: Bool
        var id: Date { date }
    }

    let days: [Day]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { DayPill(day: $0) }
        }
    }
}

private struct DayPill: View {
    let day: WeekStrip.Day

    private var isToday: Bool { Calendar.current.isDateInToday(day.date) }

    private var dotColor: Color {
        if day.isDone { return isToday ? Theme.Palette.accentDeep : Theme.Palette.accent }
        if day.isTraining { return isToday ? Theme.Palette.onAccent.opacity(0.35) : Color.white.opacity(0.35) }
        return .clear
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.7)
            Text(day.date.formatted(.dateTime.day()))
                .font(.headline.weight(isToday ? .bold : .regular))
                .monospacedDigit()
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .shadow(color: day.isDone && !isToday ? Theme.Palette.accent : .clear, radius: 3)
        }
        .foregroundStyle(isToday ? Theme.Palette.onAccent : Color.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
        .background(isToday ? Color.white : Color.white.opacity(0.06), in: Capsule())
        .overlay { Capsule().strokeBorder(Color.white.opacity(isToday ? 0 : 0.1), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.date.formatted(.dateTime.weekday(.wide).day().month())))
        .accessibilityValue(Text(day.isDone ? "тренування виконано" : (day.isTraining ? "тренувальний день" : "відпочинок")))
    }
}

/// Horizontal pills for picking one option (periods, sections).
struct PillPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [Value]
    let title: (Value) -> LocalizedStringResource

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(options, id: \.self) { option in
                    ChipToggle(title: title(option), isOn: option == selection) {
                        withAnimation(.snappy) { selection = option }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
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
                    .font(.largeTitle.weight(.light).monospacedDigit())
                    .contentTransition(.numericText(value: value))
                Text(title).eyebrow()
            }
            .frame(minWidth: 84)
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
            CircleIcon(systemImage: systemImage, size: Theme.largeTapTarget)
        }
        .buttonStyle(.plain)
    }

    private func change(by delta: Double) {
        withAnimation(.snappy) {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        }
    }
}

#Preview {
    @Previewable @State var weight = 72.5
    @Previewable @State var period = 1
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(eyebrow: Text("Понеділок, 19 жовтня"), title: Text("Сьогодні"), accent: Text("День A")) {
                CircleIconButton(systemImage: "plus", label: "Додати") {}
            }
            WeekStrip(days: (0..<7).map { offset in
                WeekStrip.Day(date: Calendar.current.date(byAdding: .day, value: offset - 2, to: .now) ?? .now, isTraining: offset % 2 == 0, isDone: offset < 2)
            })
            HStack(spacing: 8) {
                StatTile(title: "Калорії", value: "2 850", unit: "ккал", systemImage: "flame.fill")
                StatTile(title: "Серія", value: "4", unit: "тижні")
            }
            ProgressRing(progress: 0.62, isGauge: true) {
                MetricText("1 780", unit: "ккал")
            }
            .frame(width: 180, height: 180)
            PillPicker(selection: $period, options: [0, 1, 2]) { _ in "4 тижні" }
            VStack(alignment: .leading) {
                Text("Почни сьогодні").font(.title2.weight(.light))
                Button("Почати") {}.buttonStyle(.zalDark)
            }
            .highlightCardStyle()
            PhotoCard {
                Text("Жим лежачи").font(.title2.weight(.semibold))
            }
            BigStepper(title: "кг", value: $weight, step: 2.5)
            Button("Почати тренування") {}.buttonStyle(.zalPrimary)
        }
        .padding()
    }
    .zalScreen()
    .themed()
}
