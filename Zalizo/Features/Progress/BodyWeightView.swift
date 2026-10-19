import SwiftData
import SwiftUI
import ZalizoCore

/// All weigh-ins: chart, list, add (also back-dated), delete.
struct BodyWeightView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @Query private var profiles: [UserProfile]
    @State private var period: StatsPeriod = .all
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    PillPicker(selection: $period, options: StatsPeriod.allCases) { $0.title }
                    WeightSummary(
                        entries: entries.reversed(),
                        snapshot: profiles.first.map { ProfileStore.snapshot(of: $0, currentWeightKg: entries.first?.weightKg) },
                        period: period
                    )
                    .cardStyle(inset: Theme.Spacing.xl)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("Вага щодня коливається на 0,5-1,5 кг через воду і їжу. Дивись на лінію середнього за 7 днів - вона показує справжній тренд.")
                    .padding(.top, Theme.Spacing.s)
            }

            Section {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    WeightEntryRow(entry: entry, previous: index + 1 < entries.count ? entries[index + 1] : nil)
                }
                .onDelete { offsets in
                    offsets.map { entries[$0] }.forEach(context.delete)
                    try? context.save()
                }
            } header: {
                Text("Зважування")
            }
            .glassRows()
        }
        .zalScreen()
        .navigationTitle("Вага тіла")
        .toolbar {
            Button {
                showAdd = true
            } label: {
                Label("Додати", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWeightSheet(initial: entries.first?.weightKg ?? Defaults.weightKg)
                .presentationDetents([.medium, .large])
        }
    }
}

/// Date on the left, weight in thin digits and the change since the previous weigh-in on the right.
private struct WeightEntryRow: View {
    let entry: BodyWeightEntry
    let previous: BodyWeightEntry?

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.weekday(.wide))).eyebrow()
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
            }
            Spacer(minLength: Theme.Spacing.s)
            VStack(alignment: .trailing, spacing: 0) {
                MetricText(entry.weightKg.kgText, unit: "кг", size: 26)
                if let previous {
                    let change = entry.weightKg - previous.weightKg
                    Text("\(change >= 0 ? "+" : "")\(change.kgText) кг")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

struct AddWeightSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double
    @State private var date = Date.now

    init(initial: Double) {
        _weight = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Дата", selection: $date, in: ...Date.now, displayedComponents: .date)
                }
                .glassRows()
                Section {
                    WeightWheel(weightKg: $weight)
                }
                .glassRows()
            }
            .zalScreen()
            .navigationTitle("Зважування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Зберегти") {
                        ProfileStore.recordWeight(weight, on: date, context: context)
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
