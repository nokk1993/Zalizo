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
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glass)
                }
                .padding(Theme.Spacing.l)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .zalScreen()
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
                        Image(systemName: "chevron.down")
                            .accessibilityLabel(Text("Меню тренування"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
            .onAppear { model.updateLiveActivity() }
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

    private var doneSets: Int {
        session.exercises.reduce(0) { $0 + $1.workingSets.count }
    }

    private var totalSets: Int {
        session.exercises.filter { !$0.isSkipped }.reduce(0) { $0 + $1.sets.filter { !$0.isWarmup }.count }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: 6) {
                    GlowDot(size: 6)
                    Text("Тривалість").eyebrow()
                }
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    MetricText(RestTimer.format(context.date.timeIntervalSince(session.startedAt)), size: 44)
                }
                if session.isDeload {
                    Text("Розвантаження")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, 3)
                        .background(Theme.Palette.water.opacity(0.2), in: Capsule())
                }
            }
            Spacer(minLength: 0)
            ProgressRing(progress: totalSets > 0 ? Double(doneSets) / Double(totalSets) : 0, lineWidth: 8) {
                VStack(spacing: 0) {
                    Text("\(doneSets)/\(totalSets)")
                        .font(.headline.monospacedDigit())
                    Text("підходів")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)
        }
        .cardStyle(inset: Theme.Spacing.xl)
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
                            .frame(width: 64, height: 64)
                            .clipShape(.rect(cornerRadius: Theme.Radius.control))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Техніка виконання"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(performed.exerciseName)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let prescription {
                        PrescriptionSummary(performed: performed, prescription: prescription, isTimed: exercise?.progression == .timed)
                    }
                }
                Spacer(minLength: 0)
                cardMenu(exercise: exercise)
            }

            if performed.isSkipped {
                Label("Вправу пропущено", systemImage: "forward")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
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
                            ToolbarItem(placement: .topBarTrailing) {
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
            CircleIcon(systemImage: "ellipsis", size: 44)
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
        VStack(alignment: .leading, spacing: 3) {
            Text(targetText)
                .font(.title3.weight(.light).monospacedDigit())
            if let hint = PrescriptionText.hint(prescription, performed: performed) {
                Text(hint)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(hintColor)
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

    private var hintColor: Color {
        switch prescription.kind {
        case .increaseWeight: Theme.Palette.success
        case .stall: Theme.Palette.warning
        default: Theme.Palette.textSecondary
        }
    }
}

enum PrescriptionText {
    /// "4 × 6 × 72,5 кг" / "3 × 8-12 (власна вага)" / "3 × 45 с"
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
            String(localized: "Минулого разу - верх діапазону в усіх підходах. Додаємо вагу!")
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
        HStack(spacing: Theme.Spacing.xs + 2) {
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
                    Label {
                        Text(set.isWarmup ? LocalizedStringResource("Зробити робочим") : LocalizedStringResource("Позначити розминочним"))
                    } icon: {
                        Image(systemName: "thermometer.low")
                    }
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Видалити підхід", systemImage: "trash")
                }
            } label: {
                SetBadge(label: label, isWarmup: set.isWarmup, rir: set.rir)
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
                CheckCircle(isOn: set.isCompleted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(set.isCompleted ? "Підхід виконано" : "Позначити підхід виконаним"))
        }
        .opacity(set.isWarmup && !set.isCompleted ? 0.6 : 1)
        .padding(.vertical, 3)
        .padding(.horizontal, 3)
        .background(set.isCompleted ? Theme.Palette.accent.opacity(0.08) : Color.clear, in: .rect(cornerRadius: Theme.Radius.control))
    }
}

/// Set number, or a small "Р" capsule for warm-up sets; RIR underneath.
private struct SetBadge: View {
    let label: String
    let isWarmup: Bool
    let rir: Int?

    var body: some View {
        VStack(spacing: 2) {
            if isWarmup {
                Text(label)
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.Palette.warmup.opacity(0.35), in: Capsule())
            } else {
                Text(label)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            if let rir {
                Text("RIR \(rir)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(isWarmup ? Theme.Palette.textSecondary : Color.primary)
        .frame(width: 30, height: 48)
        .contentShape(Rectangle())
    }
}

/// Big round "done" toggle: lime with a dark checkmark and a glow when completed.
private struct CheckCircle: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isOn ? Theme.Palette.accent : Theme.Palette.row)
            Circle()
                .strokeBorder(Color.white.opacity(isOn ? 0 : 0.25), lineWidth: 1.5)
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(isOn ? Theme.Palette.onAccent : Color.white.opacity(0.35))
        }
        .frame(width: 46, height: 46)
        .shadow(color: Theme.Palette.accent.opacity(isOn ? 0.55 : 0), radius: 10)
        .frame(width: 48, height: 52)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}

/// - value + with large hit areas.
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
                    .font(.body.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 40)
            button("plus", delta: step)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.row, in: .rect(cornerRadius: Theme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
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
                .font(.body.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 48)
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
                ProgressRing(progress: timer.progress(at: context.date), lineWidth: 5)
                    .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 0) {
                    Text(RestTimer.format(timer.remaining(at: context.date)))
                        .font(.system(.title, design: .default, weight: .thin).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                    Text(nextSet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button("+30 с", action: onAdd)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
                CircleIconButton(systemImage: "forward.end.fill", label: "Далі", prominent: true, size: 50, action: onSkip)
            }
            .padding(Theme.Spacing.s)
            .padding(.leading, 2)
            .glassEffect(.regular, in: Capsule())
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
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
                .symbolEffect(.bounce, value: banner.id)
            VStack(alignment: .leading, spacing: 1) {
                Text(banner.text).font(.headline)
                Text(banner.exerciseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(Theme.Palette.onAccent)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Palette.accent, in: Capsule())
        .shadow(color: Theme.Palette.accent.opacity(0.55), radius: 20, y: 6)
        .padding(.top, Theme.Spacing.s)
        .padding(.horizontal, Theme.Spacing.l)
        .accessibilityElement(children: .combine)
    }
}

private struct CalibrationSheet: View {
    let onAnswer: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Скільки ще повторів ти міг би зробити?")
                .font(.title2.weight(.light))
                .fixedSize(horizontal: false, vertical: true)
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
                            .font(.title2.weight(.light).monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.glass)
                }
            }
            Text("0 - до відмови, 2 - ще два повтори в запасі.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .zalScreen()
    }
}
