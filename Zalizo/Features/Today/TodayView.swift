import SwiftData
import SwiftUI
import ZalizoCore

/// "Сьогодні": what to do today with concrete weights, week progress, weigh-in, tip of the day.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutSession> { !$0.isFinished }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var activeSessions: [WorkoutSession]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @Query(ProfileView.latestWeightDescriptor) private var latestWeights: [BodyWeightEntry]
    @Query private var profiles: [UserProfile]
    @Query private var programs: [Program]
    @Query private var settings: [AppSettings]

    @State private var plan: TodayPlanner.Plan?
    @State private var deloadReason: DeloadAdvisor.Reason?
    @State private var week = (done: 0, planned: 3, streak: 0)
    @State private var workout: WorkoutModel?
    @State private var showWellness = false
    @State private var wellnessSuggestion: WellnessPending?
    @State private var showWeighIn = false
    @State private var showQuickLog = false

    struct WellnessPending: Identifiable {
        let id = UUID()
        let model: WorkoutModel
    }

    private var isDeloadWeek: Bool { TodayPlanner.isDeloadWeek(in: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    if let session = activeSessions.first {
                        ActiveWorkoutCard(session: session) { resume(session) }
                    } else if let plan {
                        NextWorkoutCard(plan: plan, isDeload: isDeloadWeek) {
                            requestStart(day: plan.day)
                        }
                    } else {
                        ContentUnavailableView {
                            Label("Немає програми", systemImage: "list.bullet.clipboard")
                        } description: {
                            Text("Обери програму у вкладці «Програма».")
                        }
                    }

                    if activeSessions.isEmpty, let deloadReason {
                        DeloadCard(reason: deloadReason) {
                            TodayPlanner.acceptDeload(in: context)
                            reload()
                        } onPostpone: {
                            TodayPlanner.postponeDeload(in: context)
                            reload()
                        }
                    }
                    if let end = TodayPlanner.deloadEndDate(in: context) {
                        Label("Розвантажувальний тиждень до \(end.formatted(.dateTime.weekday(.wide).day().month()))", systemImage: "leaf")
                            .font(.subheadline)
                            .cardStyle()
                    }

                    HStack(spacing: Theme.Spacing.s) {
                        StatTile(title: "Цього тижня", value: "\(week.done)/\(week.planned)", unit: "трен.", systemImage: "calendar", tint: Theme.Palette.success)
                        StatTile(title: "Серія", value: "\(week.streak)", unit: "тижн. поспіль", systemImage: "flame.fill", tint: .orange)
                    }

                    WeighInCard(latest: latestWeights.first) { showWeighIn = true }

                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Label("Порада дня", systemImage: "lightbulb").font(.headline)
                        Text(DailyTips.tip())
                    }
                    .cardStyle()

                    if activeSessions.isEmpty {
                        HStack(spacing: Theme.Spacing.s) {
                            Button {
                                startFreeWorkout()
                            } label: {
                                Label("Довільне", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.glass)
                            Button {
                                showQuickLog = true
                            } label: {
                                Label("Швидкий запис", systemImage: "text.badge.plus")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Сьогодні")
            .task(id: refreshKey) { reload() }
            .fullScreenCover(item: $workout, onDismiss: reload) { model in
                WorkoutView(model: model)
            }
            .sheet(isPresented: $showWellness) {
                WellnessCheckSheet { sleep, energy, soreness in
                    showWellness = false
                    if let day = pendingDay {
                        start(day: day, wellness: (sleep, energy, soreness))
                    }
                } onSkip: {
                    showWellness = false
                    if let day = pendingDay { start(day: day, wellness: nil) }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showQuickLog, onDismiss: reload) { QuickLogView() }
            .sheet(isPresented: $showWeighIn) {
                WeighInSheet(initial: latestWeights.first?.weightKg ?? Defaults.weightKg)
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Схоже, сьогодні важкий день",
                isPresented: Binding(get: { wellnessSuggestion != nil }, set: { if !$0 && workout == nil { openPendingWellness() } }),
                titleVisibility: .visible,
                presenting: wellnessSuggestion
            ) { pending in
                Button("−1 підхід у кожній вправі") {
                    pending.model.dropOneSet()
                    present(pending.model)
                }
                Button("−5 % ваги") {
                    pending.model.reduceWeight()
                    present(pending.model)
                }
                Button("Тренуюсь за планом") { present(pending.model) }
            } message: { _ in
                Text("Можна трохи полегшити тренування. План зміниться тільки якщо ти погодишся.")
            }
        }
    }

    @State private var pendingDay: ProgramDay?

    /// Changes whenever data that affects the plan changes.
    private var refreshKey: String {
        let sessions = allSessions.filter(\.isFinished).count
        let profile = profiles.first
        return "\(sessions)-\(activeSessions.count)-\(profile?.activeProgramID?.uuidString ?? "")-\(profile?.trainingWeekdays ?? [])-\(programs.count)-\(profile?.blockStartDate?.timeIntervalSince1970 ?? 0)"
    }

    private func reload() {
        plan = TodayPlanner.plan(in: context)
        deloadReason = TodayPlanner.deloadReason(in: context)
        week = TodayPlanner.weekProgress(in: context)
        AchievementService.evaluate(in: context)
        Task { await ReminderService.refresh(in: context) }
    }

    private func requestStart(day: ProgramDay) {
        pendingDay = day
        if settings.first?.useWellnessCheck ?? true {
            showWellness = true
        } else {
            start(day: day, wellness: nil)
        }
    }

    private func start(day: ProgramDay, wellness: (Int, Int, Int)?) {
        let session = WorkoutService.start(day: day, options: .init(isDeload: isDeloadWeek), in: context)
        let model = WorkoutModel(session: session, context: context)
        pendingDay = nil
        if let wellness {
            let (sleep, energy, soreness) = wellness
            model.saveWellness(sleep: sleep, energy: energy, soreness: soreness)
            if WellnessAdvisor.suggestion(sleep: sleep, energy: energy, soreness: soreness) == .reduce {
                wellnessSuggestion = WellnessPending(model: model)
                return
            }
        }
        present(model)
    }

    private func openPendingWellness() {
        if let pending = wellnessSuggestion {
            present(pending.model)
        }
    }

    private func present(_ model: WorkoutModel) {
        wellnessSuggestion = nil
        workout = model
    }

    private func resume(_ session: WorkoutSession) {
        present(WorkoutModel(session: session, context: context))
    }

    private func startFreeWorkout() {
        let session = WorkoutService.startEmpty(title: String(localized: "Довільне тренування"), in: context)
        present(WorkoutModel(session: session, context: context))
    }
}

extension WorkoutModel: Identifiable {
    nonisolated var id: UUID { sessionID }
}

// MARK: - Cards

private struct NextWorkoutCard: View {
    let plan: TodayPlanner.Plan
    let isDeload: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if plan.next.isToday {
                Text("Сьогодні").font(.subheadline.bold()).foregroundStyle(Color.accentColor)
            } else {
                Text("Відпочинок. Наступне: \(plan.next.date.formatted(.dateTime.weekday(.abbreviated))), \(plan.day.name)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(plan.day.name).font(.title2.bold())
                Spacer()
                Text("~\(plan.estimatedMinutes) хв").font(.subheadline).foregroundStyle(.secondary)
            }
            Text(plan.program.name).font(.caption).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(plan.previews) { preview in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preview.name).font(.body.weight(.medium))
                        Text(preview.target).font(.subheadline.bold().monospacedDigit())
                        if let last = preview.last {
                            Text("минулого разу: \(last)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        if let hint = preview.hint {
                            Text(hint)
                                .font(.caption.bold())
                                .foregroundStyle(preview.kind == .increaseWeight ? Theme.Palette.success : (preview.kind == .stall ? Theme.Palette.warning : Color.secondary))
                        }
                        if let substitution = preview.substitution {
                            Label(substitution, systemImage: "arrow.triangle.swap")
                                .font(.caption2)
                                .foregroundStyle(Theme.Palette.warning)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Button(action: onStart) {
                Label(plan.next.isToday ? LocalizedStringResource("Почати тренування") : LocalizedStringResource("Почати зараз"), systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.zalPrimary)
            if isDeload {
                Text("Розвантажувальний тиждень: підходів удвічі менше, вага та сама.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

private struct ActiveWorkoutCard: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("Тренування триває", systemImage: "figure.strengthtraining.traditional")
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
            Text(session.title).font(.title2.bold())
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                Text(RestTimer.format(context.date.timeIntervalSince(session.startedAt)))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button(action: onResume) {
                Label("Продовжити", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.zalPrimary)
        }
        .cardStyle()
    }
}

private struct DeloadCard: View {
    let reason: DeloadAdvisor.Reason
    let onAccept: () -> Void
    let onPostpone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Час розвантажитись", systemImage: "leaf.fill")
                .font(.headline)
                .foregroundStyle(Theme.Palette.success)
            switch reason {
            case .scheduled(let weeks):
                Text("Ти тренуєшся \(weeks) тижнів без перерви. Тиждень з удвічі меншою кількістю підходів (вага та сама) допоможе відновитися і рости далі.")
            case .stalls(let count):
                Text("Застій у \(count) базових вправах. Легкий тиждень - найкращий спосіб зрушити з місця.")
            }
            HStack {
                Button("Почати розвантаження", action: onAccept)
                    .buttonStyle(.zalPrimary)
                Button("Пізніше", action: onPostpone)
                    .buttonStyle(.glass)
            }
        }
        .font(.subheadline)
        .cardStyle()
    }
}

private struct WeighInCard: View {
    let latest: BodyWeightEntry?
    let onWeigh: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label("Вага", systemImage: "scalemass").font(.headline)
                if let latest, Calendar.current.isDateInToday(latest.date) {
                    Text("Сьогодні: \(latest.weightKg.kgText) кг").foregroundStyle(.secondary)
                } else {
                    Text("Зважся сьогодні зранку натще").foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onWeigh) {
                Text(latest.map { Calendar.current.isDateInToday($0.date) } == true ? LocalizedStringResource("Змінити") : LocalizedStringResource("Зважитись"))
            }
            .buttonStyle(.glass)
        }
        .cardStyle()
    }
}

/// "Як ти сьогодні?" before a workout.
struct WellnessCheckSheet: View {
    let onContinue: (Int, Int, Int) -> Void
    let onSkip: () -> Void
    @State private var sleep = 4
    @State private var energy = 4
    @State private var soreness = 4

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    scale("Сон", value: $sleep, low: "погано спав", high: "виспався")
                    scale("Енергія", value: $energy, low: "дуже втомлений", high: "повний сил")
                    scale("М'язи", value: $soreness, low: "сильно болять", high: "не болять")
                } footer: {
                    Text("Якщо самопочуття погане, запропонуємо полегшити тренування. Нічого не зміниться без твого підтвердження.")
                }
            }
            .navigationTitle("Як ти сьогодні?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Пропустити", action: onSkip)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Почати") { onContinue(sleep, energy, soreness) }.bold()
                }
            }
        }
    }

    private func scale(_ title: LocalizedStringResource, value: Binding<Int>, low: LocalizedStringResource, high: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title).font(.headline)
            Picker(String(localized: title), selection: value) {
                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Quick weight entry.
struct WeighInSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double

    init(initial: Double) {
        _weight = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack {
                WeightWheel(weightKg: $weight)
                Text("Найточніше - зранку після туалету, до їжі та води.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Вага сьогодні")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Зберегти") {
                        ProfileStore.recordWeight(weight, context: context)
                        try? context.save()
                        Haptics.selection()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .previewData()
}
