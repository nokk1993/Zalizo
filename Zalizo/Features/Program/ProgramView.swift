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
                    ProgramContent(program: program, catalog: ProgramStore.catalog(exercises), profile: profileSnapshot)
                } else {
                    ContentUnavailableView {
                        Label("Немає активної програми", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Обери одну з вбудованих програм або створи власну.")
                    } actions: {
                        Button("Обрати програму") { showPicker = true }
                            .buttonStyle(.zalPrimary)
                    }
                }
                Section {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        Label("Бібліотека вправ", systemImage: "books.vertical")
                    }
                }
            }
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
}

private struct ProgramContent: View {
    @Bindable var program: Program
    let catalog: [String: ExerciseInfo]
    let profile: ProfileSnapshot
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(program.name).font(.title2.bold())
                if !program.summary.isEmpty {
                    Text(program.summary)
                }
                if !program.audience.isEmpty {
                    Text(program.audience).font(.subheadline).foregroundStyle(.secondary)
                }
                Text("Рекомендовано: \(program.recommendedWeeks) тижнів, \(profile.sessionsPerWeek) тренування на тиждень")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Theme.Spacing.xs)
            if !program.progressionNotes.isEmpty {
                DisclosureGroup("Як прогресувати") {
                    Text(program.progressionNotes).font(.subheadline)
                }
            }
        }

        Section {
            ForEach(program.orderedDays) { day in
                NavigationLink {
                    ProgramDayView(day: day)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.name).font(.headline)
                        Text("\(day.exercises.count) вправ · \(day.exercises.reduce(0) { $0 + $1.sets }) підходів")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onMove { source, destination in
                ProgramStore.reorder(program.orderedDays, from: source, to: destination) { $0.order = $1 }
                try? context.save()
            }
            Button {
                addDay()
            } label: {
                Label("Додати день", systemImage: "plus")
            }
        } header: {
            HStack {
                Text("Тренувальні дні")
                Spacer()
                EditButton().font(.caption)
            }
        } footer: {
            Text("Дні йдуть по черзі у твої тренувальні дні тижня. Утримуй і перетягни, щоб змінити порядок.")
        }

        Section {
            VolumeTable(weekly: ProgramStore.weeklyVolume(program, catalog: catalog, profile: profile))
        } header: {
            Text("Об'єм на тиждень")
        } footer: {
            Text("Робочі підходи на групу м'язів (допоміжні м'язи - ½ підходу). Орієнтир для росту м'язів - 10-20 підходів на тиждень.")
        }

        Section {
            Button {
                ProgramStore.duplicate(program, context: context)
            } label: {
                Label("Скопіювати програму", systemImage: "doc.on.doc")
            }
        } footer: {
            if program.isBuiltIn {
                Text("Вбудовану програму можна редагувати напряму або спершу зробити копію.")
            }
        }
    }

    private func addDay() {
        let day = ProgramDay(order: program.days.count, name: String(localized: "День \(program.days.count + 1)"))
        program.days.append(day)
        try? context.save()
    }
}

/// Muscle group → weekly sets with colored zones.
struct VolumeTable: View {
    let weekly: [MuscleGroup: Double]

    private var rows: [(MuscleGroup, Double)] {
        MuscleGroup.allCases.compactMap { muscle in
            let sets = weekly[muscle] ?? 0
            return sets > 0 || ProgramVolume.majorGroups.contains(muscle) ? (muscle, sets) : nil
        }
    }

    var body: some View {
        ForEach(rows, id: \.0) { muscle, sets in
            let zone = Volume.zone(weeklySets: sets)
            HStack {
                Text(muscle.title)
                Spacer()
                Text(sets.kgText).monospacedDigit().bold()
                Text(zone.title)
                    .font(.caption.bold())
                    .foregroundStyle(zone.color)
                    .frame(width: 56, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    ProgramView()
        .previewData()
}
