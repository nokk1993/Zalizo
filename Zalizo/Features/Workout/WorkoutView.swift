import SwiftData
import SwiftUI
import ZalizoCore

/// Full-screen workout mode. Designed for one hand and sweaty fingers: big targets, pre-filled values.
struct WorkoutView: View {
    @Bindable var model: WorkoutModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSummary = false
    @State private var showAddExercise = false
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.l) {
                    WorkoutHeader(session: model.session)
                    ForEach(model.session.orderedExercises) { performed in
                        ExerciseCard(performed: performed, model: model)
                    }
                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Додати вправу", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                }
                .padding(Theme.Spacing.l)
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(model.session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            dismiss()
                        } label: {
                            Label("Згорнути (тренування збережеться)", systemImage: "chevron.down")
                        }
                        Button(role: .destructive) {
                            confirmDiscard = true
                        } label: {
                            Label("Скасувати тренування", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                            .accessibilityLabel(Text("Меню тренування"))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Завершити") { showSummary = true }
                        .bold()
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let timer = model.restTimer {
                    RestTimerBar(timer: timer, nextSet: model.restNextSetText) {
                        model.addRest()
                    } onSkip: {
                        model.skipRest()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if let banner = model.recordBanner {
                    RecordBannerView(banner: banner)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: banner.id) {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation { model.recordBanner = nil }
                        }
                }
            }
            .animation(.snappy, value: model.restTimer != nil)
            .animation(.snappy, value: model.recordBanner)
            .sheet(isPresented: $showSummary) {
                WorkoutSummaryView(model: model) {
                    showSummary = false
                    dismiss()
                }
            }
            .sheet(isPresented: $showAddExercise) {
                NavigationStack {
                    ExerciseLibraryView { exercise in
                        model.add(exercise)
                        showAddExercise = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Скасувати") { showAddExercise = false }
                        }
                    }
                }
            }
            .sheet(item: $model.calibration) { _ in
                CalibrationSheet { rir in model.applyCalibration(rir: rir) }
                    .presentationDetents([.height(320)])
            }
            .confirmationDialog("Скасувати тренування?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Видалити без збереження", role: .destructive) {
                    model.discard()
                    dismiss()
                }
            } message: {
                Text("Усі записані підходи цього тренування буде видалено.")
            }
        }
    }
}

private struct WorkoutHeader: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                Label {
                    Text(RestTimer.format(context.date.timeIntervalSince(session.startedAt)))
                        .font(.title3.monospacedDigit().bold())
                } icon: {
                    Image(systemName: "stopwatch")
                }
            }
            Spacer()
            let done = session.exercises.reduce(0) { $0 + $1.workingSets.count }
            let total = session.exercises.filter { !$0.isSkipped }.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count }
            Text("\(done)/\(total) підходів")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if session.isDeload {
                Text("Розвантаження")
                    .font(.caption.bold())
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, 2)
                    .background(Theme.Palette.water.opacity(0.2), in: .capsule)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Exercise card

struct ExerciseCard: View {
    @Bindable var performed: PerformedExercise
    let model: WorkoutModel
    @State private var showReplace = false
    @State private var showPlates = false
    @State private var showWarmup = false
    @State private var showDetail = false

    var body: some View {
        let exercise = model.exercise(for: performed)
        let prescription = model.prescriptions[performed.id]
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                if let exercise {
                    Button {
                        showDetail = true
                    } label: {
                        ExerciseImage(exercise: exercise)
                            .frame(width: 56, height: 56)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Техніка виконання"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(performed.exerciseName).font(.headline)
                    if let prescription {
                        PrescriptionSummary(performed: performed, prescription: prescription, isTimed: exercise?.progression == .timed)
                    }
                }
                Spacer(minLength: 0)
                cardMenu(exercise: exercise)
            }

            if performed.isSkipped {
                Text("Вправу пропущено").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(Array(performed.orderedSets.enumerated()), id: \.element.id) { index, set in
                        SetRow(
                            set: set, label: setLabel(set, index: index),
                            weightStep: model.weightStep(for: performed),
                            isTimed: exercise?.progression == .timed
                        ) {
                            if set.isCompleted { model.uncomplete(set) } else { model.complete(set, in: performed) }
                        } onDelete: {
                            model.delete(set, from: performed)
                        } onToggleWarmup: {
                            model.toggleWarmup(set)
                        } onRIR: { rir in
                            model.setRIR(rir, for: set)
                        }
                    }
                }
                Button {
                    model.addSet(to: performed)
                } label: {
                    Label("Підхід", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)
            }
        }
        .cardStyle()
        .opacity(performed.isSkipped ? 0.6 : 1)
        .sheet(isPresented: $showReplace) {
            ReplaceExerciseSheet(performed: performed, exercise: exercise) { replacement in
                model.replace(performed, with: replacement)
                showReplace = false
            }
        }
        .sheet(isPresented: $showPlates) {
            PlateCalculatorSheet(
                initialWeight: performed.orderedSets.first { !$0.isWarmup && !$0.isCompleted }?.weightKg
                    ?? performed.orderedSets.last?.weightKg ?? 60,
                settings: model.loadSettings
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWarmup) {
            WarmupSheet(performed: performed, model: model)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDetail) {
            if let exercise {
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Готово") { showDetail = false }
                            }
                        }
                }
            }
        }
    }

    private func setLabel(_ set: SetEntry, index: Int) -> String {
        if set.isWarmup { return String(localized: "Р") }
        let workingIndex = performed.orderedSets.prefix(index + 1).filter { !$0.isWarmup }.count
        return "\(workingIndex)"
    }

    private func cardMenu(exercise: Exercise?) -> some View {
        Menu {
            Button {
                showReplace = true
            } label: {
                Label("Замінити вправу", systemImage: "arrow.triangle.swap")
            }
            if case .barbell = model.plan(for: performed).load {
                Button {
                    showPlates = true
                } label: {
                    Label("Калькулятор дисків", systemImage: "circle.grid.2x1")
                }
            }
            Button {
                showWarmup = true
            } label: {
                Label("Розминка", systemImage: "thermometer.medium")
            }
            Button {
                model.toggleSkip(performed)
            } label: {
                if performed.isSkipped {
                    Label("Повернути вправу", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Пропустити вправу", systemImage: "forward")
                }
            }
            Divider()
            Button {
                model.move(performed, by: -1)
            } label: {
                Label("Вище", systemImage: "arrow.up")
            }
            Button {
                model.move(performed, by: 1)
            } label: {
                Label("Нижче", systemImage: "arrow.down")
            }
            Button(role: .destructive) {
                model.remove(performed)
            } label: {
                Label("Прибрати з тренування", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .frame(width: 44, height: 44)
                .accessibilityLabel(Text("Дії з вправою"))
        }
    }
}

/// "4 × 6 × 72,5 кг ↑ +2,5 кг", last time, record goal.
struct PrescriptionSummary: View {
    let performed: PerformedExercise
    let prescription: Prescription
    var isTimed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(targetText)
                .font(.subheadline.bold().monospacedDigit())
            if let hint = PrescriptionText.hint(prescription, performed: performed) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(prescription.kind == .increaseWeight ? Theme.Palette.success : (prescription.kind == .stall ? Theme.Palette.warning : Color.secondary))
            }
            if let last = prescription.last {
                Text("Минулого разу: \(PrescriptionText.lastTime(last))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if prescription.bestEstimatedOneRM > 0 {
                Text("Мета: побити рекорд за оцінкою 1ПМ (зараз \(prescription.bestEstimatedOneRM.kgText) кг)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetText: String {
        PrescriptionText.target(sets: performed.plannedSets, prescription: prescription, isTimed: isTimed)
    }
}

enum PrescriptionText {
    /// "4 × 6 × 72,5 кг" / "3 × 8–12 (власна вага)" / "3 × 45 с"
    static func target(sets: Int, prescription: Prescription, isTimed: Bool) -> String {
        let reps = Set(prescription.reps)
        let repsText = reps.count == 1 ? "\(prescription.reps.first ?? 0)" : prescription.reps.map(String.init).joined(separator: "/")
        if isTimed {
            return String(localized: "\(sets) × \(repsText) с")
        }
        if prescription.kind == .calibrate {
            return String(localized: "\(sets) × \(repsText) · вагу підберемо")
        }
        if prescription.weight <= 0 {
            return String(localized: "\(sets) × \(repsText) · власна вага")
        }
        let change = prescription.weightChange
        let arrow = change > 0 ? " ↑ +\(change.preciseText) кг" : (change < 0 ? " ↓ \(change.preciseText) кг" : "")
        return String(localized: "\(sets) × \(repsText) × \(prescription.weight.preciseText) кг\(arrow)")
    }

    static func hint(_ prescription: Prescription, performed: PerformedExercise) -> String? {
        switch prescription.kind {
        case .calibrate:
            String(localized: "Перше тренування: почни з легкої ваги, після підходу вкажи, скільки ще міг би зробити")
        case .fromBaseline:
            String(localized: "Вага розрахована з твого результату в анкеті")
        case .increaseWeight:
            String(localized: "Минулого разу — верх діапазону в усіх підходах. Додаємо вагу!")
        case .addReps:
            String(localized: "Та сама вага: +1 повтор у найслабшому підході")
        case .repeatWeight:
            String(localized: "Та сама вага: набери хоча б \(performed.repMin) повторів у кожному підході")
        case .stall:
            String(localized: "Застій: −10 % ваги і знову ріст. Або заміни вправу в меню «…»")
        case .extendHold:
            String(localized: "Додай кілька секунд до утримання")
        }
    }

    /// "70 кг × 10, 10, 9, 8"
    static func lastTime(_ entry: ExerciseHistoryEntry) -> String {
        let weights = Set(entry.sets.map(\.weight))
        if weights.count == 1, let weight = weights.first {
            let reps = entry.sets.map { "\($0.reps)" }.joined(separator: ", ")
            return weight > 0 ? String(localized: "\(weight.preciseText) кг × \(reps)") : String(localized: "× \(reps)")
        }
        return entry.sets.map { "\($0.weight.preciseText)×\($0.reps)" }.joined(separator: ", ")
    }
}

// MARK: - Set row

struct SetRow: View {
    @Bindable var set: SetEntry
    let label: String
    let weightStep: Double
    var isTimed = false
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onToggleWarmup: () -> Void
    let onRIR: (Int?) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Menu {
                Section("Запас повторів (RIR)") {
                    ForEach(0...4, id: \.self) { rir in
                        Button {
                            onRIR(rir)
                        } label: {
                            if set.rir == rir {
                                Label("\(rir)", systemImage: "checkmark")
                            } else {
                                Text("\(rir)")
                            }
                        }
                    }
                    Button("Не вказувати") { onRIR(nil) }
                }
                Button {
                    onToggleWarmup()
                } label: {
                    Label(set.isWarmup ? LocalizedStringResource("Зробити робочим") : LocalizedStringResource("Позначити розминочним"), systemImage: "thermometer.low")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Видалити підхід", systemImage: "trash")
                }
            } label: {
                VStack(spacing: 0) {
                    Text(label).font(.subheadline.bold().monospacedDigit())
                    if let rir = set.rir {
                        Text("RIR \(rir)").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 44)
                .foregroundStyle(set.isWarmup ? Color.secondary : Color.primary)
            }
            .accessibilityLabel(Text(set.isWarmup ? "Розминочний підхід" : "Підхід \(label)"))

            if !isTimed {
                CompactStepper(value: $set.weightKg, step: weightStep, unit: "кг", range: 0...500)
            }
            CompactStepper(
                value: Binding(get: { Double(set.reps) }, set: { set.reps = max(0, Int($0)) }),
                step: isTimed ? 5 : 1, unit: isTimed ? "с" : "повт", range: 0...600
            )

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34))
                    .foregroundStyle(set.isCompleted ? Theme.Palette.success : Color.secondary)
                    .frame(width: 48, height: 48)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(set.isCompleted ? "Підхід виконано" : "Позначити підхід виконаним"))
        }
        .opacity(set.isWarmup && !set.isCompleted ? 0.75 : 1)
        .padding(.vertical, 2)
        .background(set.isCompleted ? Theme.Palette.success.opacity(0.08) : Color.clear, in: .rect(cornerRadius: Theme.Radius.control))
    }
}

/// − value + with large hit areas.
struct CompactStepper: View {
    @Binding var value: Double
    let step: Double
    let unit: LocalizedStringResource
    var range: ClosedRange<Double> = 0...1000

    var body: some View {
        HStack(spacing: 0) {
            button("minus", delta: -step)
            VStack(spacing: 0) {
                Text(value.preciseText)
                    .font(.body.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(minWidth: 44)
            button("plus", delta: step)
        }
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.control))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(unit))
        .accessibilityValue(Text(value.preciseText))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(step)
            case .decrement: change(-step)
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, delta: Double) -> some View {
        Button {
            change(delta)
            Haptics.selection()
        } label: {
            Image(systemName: symbol)
                .font(.body.bold())
                .frame(width: 34, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func change(_ delta: Double) {
        value = min(max(((value + delta) * 100).rounded() / 100, range.lowerBound), range.upperBound)
    }
}

// MARK: - Rest timer & banners

struct RestTimerBar: View {
    let timer: RestTimer
    let nextSet: String
    let onAdd: () -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            HStack(spacing: Theme.Spacing.m) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: timer.progress(at: context.date))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text(RestTimer.format(timer.remaining(at: context.date)))
                        .font(.title2.monospacedDigit().bold())
                    Text(nextSet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button("+30 с", action: onAdd)
                    .buttonStyle(.glass)
                Button("Далі", action: onSkip)
                    .buttonStyle(.glassProminent)
            }
            .padding(Theme.Spacing.m)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.s)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Відпочинок"))
    }
}

private struct RecordBannerView: View {
    let banner: WorkoutModel.RecordBanner

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: banner.id)
            VStack(alignment: .leading) {
                Text(banner.text).font(.headline)
                Text(banner.exerciseName).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.l)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, Theme.Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

private struct CalibrationSheet: View {
    let onAnswer: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Скільки ще повторів ти міг би зробити?")
                .font(.title3.bold())
            Text("Чесна відповідь допоможе точно підібрати робочу вагу для наступних підходів.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: Theme.Spacing.s) {
                ForEach(0...5, id: \.self) { rir in
                    Button {
                        onAnswer(rir)
                        dismiss()
                    } label: {
                        Text(rir == 5 ? "5+" : "\(rir)")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.glass)
                }
            }
            Text("0 — до відмови, 2 — ще два повтори в запасі.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.xl)
    }
}
