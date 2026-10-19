import SwiftData
import SwiftUI
import ZalizoCore

/// Body measurements: latest value and change per kind, charts, add/delete.
struct MeasurementsView: View {
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(MeasurementKind.allCases, id: \.self) { kind in
                    let points = measurements.filter { $0.kind == kind }
                    NavigationLink {
                        MeasurementDetailView(kind: kind)
                    } label: {
                        LabeledContent {
                            if let last = points.last {
                                VStack(alignment: .trailing) {
                                    Text("\(last.valueCm.kgText) см").monospacedDigit()
                                    if let change = StatsService.change(points.map { .init(date: $0.date, value: $0.valueCm) }) {
                                        Text("\(change >= 0 ? "+" : "")\(change.kgText) см")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text("—").foregroundStyle(.secondary)
                            }
                        } label: {
                            Text(kind.title)
                        }
                    }
                }
            } footer: {
                Text("Міряй зранку, в одних і тих самих точках, сантиметровою стрічкою без натягу. Раз на 2–4 тижні достатньо.")
            }
        }
        .navigationTitle("Заміри")
        .toolbar {
            Button {
                showAdd = true
            } label: {
                Label("Додати заміри", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAdd) { AddMeasurementsSheet() }
    }
}

struct MeasurementDetailView: View {
    let kind: MeasurementKind
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var all: [BodyMeasurement]

    private var entries: [BodyMeasurement] { all.filter { $0.kind == kind } }

    var body: some View {
        List {
            if entries.count >= 2 {
                Section {
                    TrendLineChart(points: entries.reversed().map { .init(date: $0.date, value: $0.valueCm) }, valueLabel: kind.title, unit: "см")
                        .frame(height: 200)
                }
            }
            Section {
                ForEach(entries) { entry in
                    LabeledContent {
                        Text("\(entry.valueCm.kgText) см").monospacedDigit()
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
        .navigationTitle(Text(kind.title))
    }
}

struct AddMeasurementsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var values: [MeasurementKind: Double] = [:]

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Дата", selection: $date, in: ...Date.now, displayedComponents: .date)
                Section {
                    ForEach(MeasurementKind.allCases, id: \.self) { kind in
                        HStack {
                            Text(kind.title)
                            Spacer()
                            TextField("см", value: binding(kind), format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                } footer: {
                    Text("Заповни лише ті заміри, які зробив.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Нові заміри")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") { save() }
                        .bold()
                        .disabled(values.values.allSatisfy { $0 <= 0 })
                }
            }
        }
    }

    private func binding(_ kind: MeasurementKind) -> Binding<Double?> {
        Binding(get: { values[kind] }, set: { values[kind] = $0 })
    }

    private func save() {
        for (kind, value) in values where value > 0 {
            context.insert(BodyMeasurement(date: date, kind: kind, valueCm: value))
        }
        try? context.save()
        dismiss()
    }
}
