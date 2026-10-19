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
                    NavigationLink {
                        MeasurementDetailView(kind: kind)
                    } label: {
                        MeasurementRow(kind: kind, points: measurements.filter { $0.kind == kind })
                    }
                }
            } footer: {
                Text("Міряй зранку, в одних і тих самих точках, сантиметровою стрічкою без натягу. Раз на 2-4 тижні достатньо.")
            }
            .glassRows()
        }
        .zalScreen()
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

/// Kind on the left; latest value in thin digits and the change on the right.
private struct MeasurementRow: View {
    let kind: MeasurementKind
    let points: [BodyMeasurement]

    var body: some View {
        HStack {
            Text(kind.title).font(.body.weight(.medium))
            Spacer(minLength: Theme.Spacing.s)
            if let last = points.last {
                VStack(alignment: .trailing, spacing: 0) {
                    MetricText(last.valueCm.kgText, unit: "см", size: 24)
                    if let change = StatsService.change(points.map { .init(date: $0.date, value: $0.valueCm) }) {
                        Text("\(change >= 0 ? "+" : "")\(change.kgText) см")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("-").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct MeasurementDetailView: View {
    let kind: MeasurementKind
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var all: [BodyMeasurement]

    private var entries: [BodyMeasurement] { all.filter { $0.kind == kind } }

    var body: some View {
        List {
            if let latest = entries.first {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Останній замір").eyebrow()
                            MetricText(latest.valueCm.kgText, unit: "см", size: 48)
                        }
                        if entries.count >= 2 {
                            TrendLineChart(points: entries.reversed().map { .init(date: $0.date, value: $0.valueCm) }, valueLabel: kind.title, unit: "см")
                                .frame(height: 200)
                        }
                    }
                    .cardStyle(inset: Theme.Spacing.xl)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            Section {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                        Spacer()
                        Text("\(entry.valueCm.kgText) см")
                            .font(.body.weight(.light).monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                }
                .onDelete { offsets in
                    offsets.map { entries[$0] }.forEach(context.delete)
                    try? context.save()
                }
            } header: {
                Text("Історія")
            }
            .glassRows()
        }
        .zalScreen()
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
                Section {
                    DatePicker("Дата", selection: $date, in: ...Date.now, displayedComponents: .date)
                }
                .glassRows()
                Section {
                    ForEach(MeasurementKind.allCases, id: \.self) { kind in
                        HStack {
                            Text(kind.title)
                            Spacer()
                            TextField("см", value: binding(kind), format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body.monospacedDigit())
                                .frame(width: 80)
                        }
                    }
                } footer: {
                    Text("Заповни лише ті заміри, які зробив.")
                }
                .glassRows()
            }
            .scrollDismissesKeyboard(.interactively)
            .zalScreen()
            .navigationTitle("Нові заміри")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
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
