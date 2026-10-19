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
                Picker("Період", selection: $period) {
                    ForEach(StatsPeriod.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                WeightSummary(
                    entries: entries.reversed(),
                    snapshot: profiles.first.map { ProfileStore.snapshot(of: $0, currentWeightKg: entries.first?.weightKg) },
                    period: period
                )
            } footer: {
                Text("Вага щодня коливається на 0,5–1,5 кг через воду і їжу. Дивись на лінію середнього за 7 днів — вона показує справжній тренд.")
            }
            Section("Зважування") {
                ForEach(entries) { entry in
                    LabeledContent {
                        Text("\(entry.weightKg.kgText) кг").monospacedDigit()
                    } label: {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .onDelete { offsets in
                    offsets.map { entries[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
        }
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
                DatePicker("Дата", selection: $date, in: ...Date.now, displayedComponents: .date)
                WeightWheel(weightKg: $weight)
            }
            .navigationTitle("Зважування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
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
