import SwiftData
import SwiftUI
import ZalizoCore

/// "Програма" tab: active program, its days, weekly volume, library.
struct ProgramView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query private var exercises: [Exercise]
    @State private var showPicker = false

    private var profileSnapshot: ProfileSnapshot {
        profiles.first.map { ProfileStore.snapshot(of: $0, currentWeightKg: nil) } ?? ProfileSnapshot()
    }

    private var activeProgram: Program? {
        guard let id = profiles.first?.activeProgramID else { return nil }
        return programs.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            List {
                if let program = activeProgram {
                    ProgramContent(
                        program: program,
                        exercises: exercises,
                        catalog: ProgramStore.catalog(exercises),
                        profile: profileSnapshot
                    )
                } else {
                    emptyState
                }
                Section {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            IconBadge(systemImage: "books.vertical", tint: Theme.Palette.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Бібліотека вправ").font(.headline)
                                Text("Техніка, фото, альтернативи")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .glassRows()
            }
            .zalScreen()
            .navigationTitle("Програма")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Змінити програму", systemImage: "arrow.left.arrow.right")
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                NavigationStack { ProgramPickerView() }
            }
            .task {
                if activeProgram == nil {
                    _ = ProgramStore.activeProgram(in: context)
                }
            }
        }
    }

    private var emptyState: some View {
        Section {
            ContentUnavailableView {
                Label("Немає активної програми", systemImage: "list.bullet.clipboard")
            } description: {
                Text("Обери одну з вбудованих програм або створи власну.")
            } actions: {
                Button("Обрати програму") { showPicker = true }
                    .buttonStyle(.zalPrimary)
            }
            .listRowBackground(Color.clear)
        }
    }
}

private struct ProgramContent: View {
    @Bindable var program: Program
    let exercises: [Exercise]
    let catalog: [String: ExerciseInfo]
    let profile: ProfileSnapshot
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            ProgramHero(program: program, sessionsPerWeek: profile.sessionsPerWeek)
                .cardRow()
        }

        if !program.progressionNotes.isEmpty {
            Section {
                DisclosureGroup {
                    Text(program.progressionNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.xs)
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "chart.line.uptrend.xyaxis", tint: Theme.Palette.accent)
                        Text("Як прогресувати").font(.headline)
                    }
                }
            }
            .glassRows()
        }

        daysSection

        Section {
            VolumeTable(weekly: ProgramStore.weeklyVolume(program, catalog: catalog, profile: profile))
                .padding(.vertical, Theme.Spacing.s)
        } header: {
            SectionHeader("Об'єм на тиждень")
                .textCase(nil)
                .foregroundStyle(.primary)
        } footer: {
            Text("Робочі підходи на групу м'язів (допоміжні м'язи - ½ підходу). Орієнтир для росту м'язів - 10-20 підходів на тиждень.")
        }
        .glassRows()

        Section {
            Button {
                ProgramStore.duplicate(program, context: context)
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    IconBadge(systemImage: "doc.on.doc")
                    Text("Скопіювати програму").foregroundStyle(.primary)
                }
            }
        } footer: {
            if program.isBuiltIn {
                Text("Вбудовану програму можна редагувати напряму або спершу зробити копію.")
            }
        }
        .glassRows()
    }

    private var daysSection: some View {
        Section {
            ForEach(program.orderedDays) { day in
                ZStack {
                    NavigationLink {
                        ProgramDayView(day: day)
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)
                    DayCard(day: day, cover: cover(for: day), minutes: minutes(for: day))
                }
                .cardRow()
            }
            .onMove { source, destination in
                ProgramStore.reorder(program.orderedDays, from: source, to: destination) { $0.order = $1 }
                try? context.save()
            }
            Button {
                addDay()
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    IconBadge(systemImage: "plus", tint: Theme.Palette.accent)
                    Text("Додати день").foregroundStyle(.primary)
                }
            }
            .listRowBackground(Theme.Palette.row)
        } header: {
            SectionHeader(title: "Тренувальні дні") {
                EditButton().font(.subheadline.weight(.semibold))
            }
            .textCase(nil)
            .foregroundStyle(.primary)
        } footer: {
            Text("Дні йдуть по черзі у твої тренувальні дні тижня. Утримуй і перетягни, щоб змінити порядок.")
        }
    }

    /// Photo of the first exercise actually performed that day (after substitutions).
    private func cover(for day: ProgramDay) -> Exercise? {
        guard let first = day.orderedExercises.first else { return nil }
        let slug = ProgramStore.resolve(first, catalog: catalog, profile: profile).slug
        return exercises.first { $0.slug == slug }
    }

    private func minutes(for day: ProgramDay) -> Int? {
        let planned = day.orderedExercises
        guard !planned.isEmpty else { return nil }
        var warmed: Set<MuscleGroup> = []
        let items = planned.map { item -> SessionEstimate.Item in
            let info = catalog[ProgramStore.resolve(item, catalog: catalog, profile: profile).slug]
            let primary = Set(info?.primary ?? [])
            let warmup = info?.mechanic == .compound && !primary.isSubset(of: warmed)
            warmed.formUnion(primary)
            return SessionEstimate.Item(sets: item.sets, restSeconds: item.restSeconds, hasWarmup: warmup)
        }
        return SessionEstimate.minutes(items)
    }

    private func addDay() {
        let day = ProgramDay(order: program.days.count, name: String(localized: "День \(program.days.count + 1)"))
        program.days.append(day)
        try? context.save()
    }
}

/// Lime hero: program name, summary and the main numbers.
private struct ProgramHero: View {
    let program: Program
    let sessionsPerWeek: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Активна програма").eyebrow()
            Text(program.name)
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            if !program.summary.isEmpty {
                Text(program.summary)
                    .font(.subheadline.weight(.light))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                metric("\(sessionsPerWeek)", caption: "трен. на тиждень")
                metric("\(program.recommendedWeeks)", caption: "тижн. програми")
                metric("\(program.days.count)", caption: "дн. у циклі")
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Рекомендовано: \(program.recommendedWeeks) тижнів, \(sessionsPerWeek) тренування на тиждень"))
            if !program.audience.isEmpty {
                Text(program.audience)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .highlightCardStyle()
    }

    private func metric(_ value: String, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MetricText(value, size: 38)
            Text(caption)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Big photo card of a training day.
private struct DayCard: View {
    let day: ProgramDay
    let cover: Exercise?
    let minutes: Int?

    private var totalSets: Int { day.exercises.reduce(0) { $0 + $1.sets } }

    var body: some View {
        PhotoCard(exercise: cover, minHeight: 190) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("День \(day.order + 1)").eyebrow()
                Text(day.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                if !day.focus.isEmpty {
                    Text(day.focus)
                        .font(.subheadline.weight(.light))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(2)
                }
                HStack(spacing: Theme.Spacing.s) {
                    InfoPill(text: "\(day.exercises.count) вправ", systemImage: "dumbbell")
                    InfoPill(text: "\(totalSets) підходів", systemImage: "square.stack.3d.up")
                    if let minutes {
                        InfoPill(text: "~\(minutes) хв", systemImage: "clock")
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Відкрити день"))
    }
}

/// Small translucent capsule with an icon and text, readable on photos.
private struct InfoPill: View {
    let text: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.Palette.accent)
            Text(text)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1) }
    }
}

private extension View {
    /// List row that shows its own card instead of the system row background.
    func cardRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: 0, bottom: Theme.Spacing.s, trailing: 0))
    }
}

/// Muscle group → weekly sets with thin bars and colored zones.
struct VolumeTable: View {
    let weekly: [MuscleGroup: Double]

    /// Bar length that corresponds to a full bar.
    fileprivate static let scaleMax = 25.0

    private var rows: [(MuscleGroup, Double)] {
        MuscleGroup.allCases.compactMap { muscle in
            let sets = weekly[muscle] ?? 0
            return sets > 0 || ProgramVolume.majorGroups.contains(muscle) ? (muscle, sets) : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.l) {
                legend(Theme.Palette.blue, "до 10")
                legend(Theme.Palette.accent, "10-20")
                legend(Theme.Palette.warning, "понад 20")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

            ForEach(rows, id: \.0) { muscle, sets in
                VolumeRow(muscle: muscle, sets: sets)
            }
        }
    }

    private func legend(_ color: Color, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            GlowDot(color: color, size: 6)
            Text(text)
        }
    }
}

private struct VolumeRow: View {
    let muscle: MuscleGroup
    let sets: Double

    private var zone: Volume.Zone { Volume.zone(weeklySets: sets) }

    private var color: Color {
        switch zone {
        case .low: Theme.Palette.blue
        case .optimal: Theme.Palette.accent
        case .high: Theme.Palette.warning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(muscle.title).font(.subheadline)
                Spacer()
                Text(sets.kgText)
                    .font(.title3.weight(.light).monospacedDigit())
                Text(zone.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 56, alignment: .trailing)
            }
            VolumeBar(fraction: min(sets / VolumeTable.scaleMax, 1), color: color)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Thin capsule bar with marks at 10 and 20 sets.
private struct VolumeBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                if fraction > 0 {
                    Capsule()
                        .fill(color)
                        .frame(width: max(5, width * fraction))
                        .shadow(color: color.opacity(0.6), radius: 4)
                }
                ForEach([10.0, 20.0], id: \.self) { mark in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1, height: 9)
                        .offset(x: width * mark / VolumeTable.scaleMax)
                }
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

#Preview {
    ProgramView()
        .previewData()
}
