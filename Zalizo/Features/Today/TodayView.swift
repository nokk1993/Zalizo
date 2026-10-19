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
    @Query private var exercises: [Exercise]

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
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    WeekStrip(days: weekDays)
                    mainCard
                    deloadCards
                    WeekProgressCard(done: week.done, planned: week.planned, streak: week.streak)
                    WeighInCard(latest: latestWeights.first) { showWeighIn = true }
                    TipCard()
                    if activeSessions.isEmpty {
                        extraActions
                    }
                }
                .padding(Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .zalScreen()
            .navigationTitle("Сьогодні")
            .task(id: refreshKey) { reload() }
            .fullScreenCover(item: $workout, onDismiss: { reload() }) { model in
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
            .sheet(isPresented: $showQuickLog, onDismiss: { reload() }) { QuickLogView() }
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

    // MARK: - Sections

    @ViewBuilder private var mainCard: some View {
        if let session = activeSessions.first {
            ActiveWorkoutCard(session: session) { resume(session) }
        } else if let plan {
            NextWorkoutCard(plan: plan, exercise: heroExercise(for: plan), isDeload: isDeloadWeek) {
                requestStart(day: plan.day)
            }
        } else {
            ContentUnavailableView {
                Label("Немає програми", systemImage: "list.bullet.clipboard")
            } description: {
                Text("Обери програму у вкладці «Програма».")
            }
            .cardStyle()
        }
    }

    @ViewBuilder private var deloadCards: some View {
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
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: "leaf", tint: Theme.Palette.success)
                Text("Розвантажувальний тиждень до \(end.formatted(.dateTime.weekday(.wide).day().month()))")
                    .font(.subheadline)
            }
            .cardStyle(tint: Theme.Palette.success)
        }
    }

    private var extraActions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader("Поза програмою")
            HStack(spacing: Theme.Spacing.s) {
                Button {
                    startFreeWorkout()
                } label: {
                    Label("Довільне", systemImage: "plus")
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

    /// Current Monday-Sunday week: planned training weekdays and days with a finished workout.
    private var weekDays: [WeekStrip.Day] {
        let calendar = Calendar.iso
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let saved = profiles.first?.weekdays ?? []
        let training = Set(saved.isEmpty ? Defaults.trainingDays : saved)
        let finished = allSessions.filter { $0.isFinished && interval.containsHalfOpen($0.startedAt) }.map(\.startedAt)
        return (0..<7).compactMap { offset -> WeekStrip.Day? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            return WeekStrip.Day(
                date: date,
                isTraining: training.contains(Weekday.from(date: date, calendar: calendar)),
                isDone: finished.contains { calendar.isDate($0, inSameDayAs: date) }
            )
        }
    }

    /// Photo for the hero card: the first exercise of the day (after substitutions).
    private func heroExercise(for plan: TodayPlanner.Plan) -> Exercise? {
        if let name = plan.previews.first?.name, let match = exercises.first(where: { $0.nameUk == name }) {
            return match
        }
        guard let slug = plan.day.orderedExercises.first?.exerciseSlug else { return nil }
        return exercises.first { $0.slug == slug }
    }

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
    let exercise: Exercise?
    let isDeload: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PhotoCard(exercise: exercise, minHeight: 250) {
                hero
            }
            if !plan.previews.isEmpty {
                PreviewList(previews: plan.previews)
            }
            Button(action: onStart) {
                Label {
                    Text(plan.next.isToday ? LocalizedStringResource("Почати тренування") : LocalizedStringResource("Почати зараз"))
                } icon: {
                    Image(systemName: "play.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.zalPrimary)
            if isDeload {
                Text("Розвантажувальний тиждень: підходів удвічі менше, вага та сама.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                GlowDot(color: plan.next.isToday ? Theme.Palette.accent : Theme.Palette.blue, size: 7)
                eyebrowText.eyebrow()
            }
            Text(plan.day.name)
                .font(.largeTitle.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            HStack(spacing: Theme.Spacing.s) {
                Text(plan.program.name).lineLimit(1)
                Text("·")
                Text("~\(plan.estimatedMinutes) хв").monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(Color.white.opacity(0.75))
        }
        .accessibilityElement(children: .combine)
    }

    private var eyebrowText: Text {
        if plan.next.isToday {
            Text("Сьогодні")
        } else {
            Text("Відпочинок. Наступне: \(plan.next.date.formatted(.dateTime.weekday(.wide)))")
        }
    }
}

/// Exercises of the next workout with today's targets.
private struct PreviewList: View {
    let previews: [TodayPlanner.ExercisePreview]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(previews.enumerated()), id: \.element.id) { index, preview in
                if index > 0 {
                    Divider()
                }
                PreviewRow(number: index + 1, preview: preview)
                    .padding(.vertical, Theme.Spacing.m)
            }
        }
        .cardStyle(inset: Theme.Spacing.l)
    }
}

private struct PreviewRow: View {
    let number: Int
    let preview: TodayPlanner.ExercisePreview

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Text("\(number)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Theme.Palette.row, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.name).font(.body.weight(.medium))
                Text(preview.target)
                    .font(.title3.weight(.light).monospacedDigit())
                if let last = preview.last {
                    Text("минулого разу: \(last)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let hint = preview.hint {
                    HStack(spacing: 6) {
                        GlowDot(color: hintColor, size: 6)
                        Text(hint)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(hintColor)
                    }
                }
                if let substitution = preview.substitution {
                    Label(substitution, systemImage: "arrow.triangle.swap")
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.warning)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var hintColor: Color {
        switch preview.kind {
        case .increaseWeight: Theme.Palette.success
        case .stall: Theme.Palette.warning
        default: Theme.Palette.textSecondary
        }
    }
}

private struct ActiveWorkoutCard: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                Text("Тренування триває")
            }
            .eyebrow()
            Text(session.title)
                .font(.title.weight(.bold))
                .lineLimit(2)
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                MetricText(RestTimer.format(context.date.timeIntervalSince(session.startedAt)), size: 56)
            }
            Button(action: onResume) {
                Label("Продовжити", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.zalDark)
        }
        .highlightCardStyle()
    }
}

private struct WeekProgressCard: View {
    let done: Int
    let planned: Int
    let streak: Int

    private var progress: Double {
        planned > 0 ? Double(done) / Double(planned) : 0
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            ProgressRing(progress: progress, lineWidth: 9) {
                VStack(spacing: 0) {
                    Text("\(done)/\(planned)")
                        .font(.title2.weight(.light).monospacedDigit())
                    Text("трен.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Цього тижня").eyebrow()
                statusText.font(.headline)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Theme.Palette.warning)
                    Text("Серія: \(streak) тижн. поспіль")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private var statusText: Text {
        if done >= planned {
            Text("План тижня виконано")
        } else {
            Text("Ще \(planned - done) трен. до плану")
        }
    }
}

private struct DeloadCard: View {
    let reason: DeloadAdvisor.Reason
    let onAccept: () -> Void
    let onPostpone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: "leaf.fill", tint: Theme.Palette.success)
                Text("Час розвантажитись").font(.headline)
            }
            Group {
                switch reason {
                case .scheduled(let weeks):
                    Text("Ти тренуєшся \(weeks) тижнів без перерви. Тиждень з удвічі меншою кількістю підходів (вага та сама) допоможе відновитися і рости далі.")
                case .stalls(let count):
                    Text("Застій у \(count) базових вправах. Легкий тиждень - найкращий спосіб зрушити з місця.")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack(spacing: Theme.Spacing.s) {
                Button("Почати розвантаження", action: onAccept)
                    .buttonStyle(.zalPrimary)
                Button("Пізніше", action: onPostpone)
                    .buttonStyle(.glass)
            }
        }
        .cardStyle(tint: Theme.Palette.success)
    }
}

private struct WeighInCard: View {
    let latest: BodyWeightEntry?
    let onWeigh: () -> Void

    private var weighedToday: BodyWeightEntry? {
        guard let latest, Calendar.current.isDateInToday(latest.date) else { return nil }
        return latest
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconBadge(systemImage: "scalemass", tint: Theme.Palette.blue, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Вага").font(.headline)
                if let today = weighedToday {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text(today.weightKg.kgText)
                            .font(.title2.weight(.light).monospacedDigit())
                        Text("кг сьогодні")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Зважся сьогодні зранку натще")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button(action: onWeigh) {
                Text(weighedToday == nil ? LocalizedStringResource("Зважитись") : LocalizedStringResource("Змінити"))
            }
            .buttonStyle(.glass)
        }
        .cardStyle()
    }
}

private struct TipCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                GlowDot(size: 6)
                Text("Порада дня").eyebrow()
            }
            Text(DailyTips.tip())
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    WellnessScale(title: "Сон", value: $sleep, low: "погано спав", high: "виспався")
                    WellnessScale(title: "Енергія", value: $energy, low: "дуже втомлений", high: "повний сил")
                    WellnessScale(title: "М'язи", value: $soreness, low: "сильно болять", high: "не болять")
                    Text("Якщо самопочуття погане, запропонуємо полегшити тренування. Нічого не зміниться без твого підтвердження.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.l)
            }
            .zalScreen()
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
}

/// 1-5 scale as round pills.
private struct WellnessScale: View {
    let title: LocalizedStringResource
    @Binding var value: Int
    let low: LocalizedStringResource
    let high: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(title).font(.headline)
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { option in
                    pill(option)
                }
            }
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func pill(_ option: Int) -> some View {
        let isSelected = option == value
        return Button {
            Haptics.selection()
            withAnimation(.snappy) { value = option }
        } label: {
            Text("\(option)")
                .font(.title3.weight(isSelected ? .bold : .light).monospacedDigit())
                .foregroundStyle(isSelected ? Theme.Palette.onAccent : Color.primary)
                .frame(width: 50, height: 50)
                .background(isSelected ? Theme.Palette.accent : Theme.Palette.row, in: Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1) }
                .shadow(color: Theme.Palette.accent.opacity(isSelected ? 0.45 : 0), radius: 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(option)"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
            VStack(spacing: Theme.Spacing.l) {
                WeightWheel(weightKg: $weight)
                    .cardStyle()
                Text("Найточніше - зранку після туалету, до їжі та води.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zalScreen()
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
