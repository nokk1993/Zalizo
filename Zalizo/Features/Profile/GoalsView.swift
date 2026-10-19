import SwiftData
import SwiftUI
import ZalizoCore

/// Goals with progress bars and forecasts + restrained achievements.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \Achievement.unlockedAt) private var achievements: [Achievement]
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                if goals.isEmpty {
                    Text("Постав ціль: вага тіла, сила у вправі, кількість тренувань за місяць або замір.")
                        .foregroundStyle(.secondary)
                }
                ForEach(goals) { goal in
                    GoalRow(goal: goal, status: AchievementService.status(for: goal, in: context))
                }
                .onDelete { offsets in
                    offsets.map { goals[$0] }.forEach(context.delete)
                    try? context.save()
                }
                Button {
                    showAdd = true
                } label: {
                    Label("Нова ціль", systemImage: "plus")
                }
            } header: {
                Text("Цілі")
            }

            Section("Досягнення") {
                let unlocked = Set(achievements.map(\.key))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.m)], spacing: Theme.Spacing.m) {
                    ForEach(AchievementKey.allCases, id: \.self) { key in
                        AchievementBadge(key: key, unlockedAt: achievements.first { $0.key == key.rawValue }?.unlockedAt, isUnlocked: unlocked.contains(key.rawValue))
                    }
                }
                .padding(.vertical, Theme.Spacing.s)
            }
        }
        .navigationTitle("Цілі і досягнення")
        .sheet(isPresented: $showAdd) { AddGoalSheet() }
        .task { AchievementService.evaluate(in: context) }
    }
}

private struct GoalRow: View {
    let goal: Goal
    let status: GoalProgress.Status

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(goal.title).font(.headline)
                Spacer()
                if status.isAchieved {
                    Label("Досягнуто", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Palette.success)
                }
            }
            ProgressView(value: status.fraction)
                .tint(status.isAchieved ? Theme.Palette.success : Color.accentColor)
            HStack {
                Text("\(status.current.kgText) → \(goal.targetValue.kgText) \(unit)")
                    .font(.caption.monospacedDigit())
                Spacer()
                if let deadline = goal.deadline {
                    Text("до \(deadline.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            if !status.isAchieved {
                Text(forecastText).font(.caption).foregroundStyle(status.onTrack == false ? Theme.Palette.warning : Color.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var unit: String {
        switch goal.kind {
        case .bodyWeight, .liftWeight: String(localized: "кг")
        case .workoutsPerMonth: String(localized: "трен.")
        case .measurement: String(localized: "см")
        }
    }

    private var forecastText: String {
        if goal.kind == .workoutsPerMonth {
            return String(localized: "Цього місяця: \(Int(status.current)) з \(Int(goal.targetValue))")
        }
        guard let forecast = status.forecastDate else {
            return String(localized: "Прогноз з'явиться, коли буде більше даних за 1–2 тижні")
        }
        let date = forecast.formatted(date: .abbreviated, time: .omitted)
        if status.onTrack == false {
            return String(localized: "За поточним темпом — до \(date), пізніше за дедлайн")
        }
        return String(localized: "За поточним темпом — до \(date)")
    }
}

private struct AchievementBadge: View {
    let key: AchievementKey
    let unlockedAt: Date?
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: key.systemImage)
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(isUnlocked ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08), in: .circle)
                .foregroundStyle(isUnlocked ? Color.accentColor : Color.secondary.opacity(0.5))
            Text(key.title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(isUnlocked ? "отримано" : "ще ні"))
    }
}

extension AchievementKey {
    var title: LocalizedStringResource {
        switch self {
        case .firstWorkout: "Перше тренування"
        case .workouts10: "10 тренувань"
        case .workouts50: "50 тренувань"
        case .workouts100: "100 тренувань"
        case .streak4Weeks: "4 тижні без пропусків"
        case .streak12Weeks: "12 тижнів без пропусків"
        case .firstRecord: "Перший рекорд"
        case .benchBodyweight: "Жим вагою свого тіла"
        case .squatOneAndHalf: "Присід 1,5 ваги тіла"
        case .tonnage100k: "100 тонн за весь час"
        case .firstDeload: "Розумне розвантаження"
        case .goalReached: "Ціль досягнуто"
        }
    }

    var systemImage: String {
        switch self {
        case .firstWorkout: "figure.strengthtraining.traditional"
        case .workouts10: "10.circle"
        case .workouts50: "50.circle"
        case .workouts100: "rosette"
        case .streak4Weeks: "calendar.badge.checkmark"
        case .streak12Weeks: "calendar"
        case .firstRecord: "trophy"
        case .benchBodyweight: "scalemass"
        case .squatOneAndHalf: "figure.strengthtraining.functional"
        case .tonnage100k: "shippingbox"
        case .firstDeload: "leaf"
        case .goalReached: "flag.checkered"
        }
    }
}

private struct AddGoalSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.nameUk) private var exercises: [Exercise]
    @State private var kind: GoalKind = .bodyWeight
    @State private var target: Double = 75
    @State private var exerciseSlug = KeyLift.benchPress.rawValue
    @State private var measurement: MeasurementKind = .bicepsRight
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Picker("Тип цілі", selection: $kind) {
                    Text("Вага тіла").tag(GoalKind.bodyWeight)
                    Text("Сила у вправі").tag(GoalKind.liftWeight)
                    Text("Тренувань за місяць").tag(GoalKind.workoutsPerMonth)
                    Text("Замір").tag(GoalKind.measurement)
                }
                switch kind {
                case .liftWeight:
                    Picker("Вправа", selection: $exerciseSlug) {
                        ForEach(exercises.filter { $0.mechanic == .compound }) { Text($0.nameUk).tag($0.slug) }
                    }
                case .measurement:
                    Picker("Замір", selection: $measurement) {
                        ForEach(MeasurementKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                default:
                    EmptyView()
                }
                Stepper(value: $target, in: kind == .workoutsPerMonth ? 1...31 : 1...400, step: kind == .workoutsPerMonth ? 1 : 0.5) {
                    LabeledContent(kind == .liftWeight ? "Ціль (1ПМ), кг" : "Ціль") {
                        Text(target.kgText).monospacedDigit()
                    }
                }
                Toggle("Дедлайн", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("До", selection: $deadline, in: Date.now..., displayedComponents: .date)
                }
            }
            .navigationTitle("Нова ціль")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newKind in target = defaultTarget(newKind) }
            .onAppear { target = defaultTarget(kind) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Зберегти") { save() }.bold() }
            }
        }
    }

    private func currentValue(_ kind: GoalKind) -> Double {
        let probe = Goal(kind: kind, title: "", startValue: 0, targetValue: 0)
        probe.exerciseSlug = exerciseSlug
        probe.measurementKindRaw = measurement.rawValue
        return AchievementService.history(for: probe, in: context).max { $0.date < $1.date }?.value ?? 0
    }

    private func defaultTarget(_ kind: GoalKind) -> Double {
        switch kind {
        case .bodyWeight: ((currentValue(kind) + 5) * 2).rounded() / 2
        case .liftWeight: max(20, ((currentValue(kind) + 10) / 2.5).rounded() * 2.5)
        case .workoutsPerMonth: 12
        case .measurement: max(10, currentValue(kind) + 2)
        }
    }

    private func save() {
        let start = currentValue(kind)
        let title: String = switch kind {
        case .bodyWeight: String(localized: "Вага \(target.kgText) кг")
        case .liftWeight: String(localized: "\(exercises.first { $0.slug == exerciseSlug }?.nameUk ?? "") — \(target.kgText) кг")
        case .workoutsPerMonth: String(localized: "\(Int(target)) тренувань за місяць")
        case .measurement: String(localized: "\(String(localized: measurement.title)) — \(target.kgText) см")
        }
        let goal = Goal(kind: kind, title: title, startValue: kind == .workoutsPerMonth ? 0 : start, targetValue: target)
        goal.exerciseSlug = kind == .liftWeight ? exerciseSlug : nil
        goal.measurementKindRaw = kind == .measurement ? measurement.rawValue : nil
        goal.deadline = hasDeadline ? deadline : nil
        context.insert(goal)
        try? context.save()
        dismiss()
    }
}
