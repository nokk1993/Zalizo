import SwiftData
import SwiftUI
import ZalizoCore

/// Choose, create or delete programs.
struct ProgramPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query private var profiles: [UserProfile]
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newDays = 3
    @State private var programToDelete: Program?

    private var activeID: UUID? { profiles.first?.activeProgramID }

    var body: some View {
        List {
            Section("Вбудовані") {
                ForEach(programs.filter(\.isBuiltIn)) { program in
                    row(program)
                }
            }
            let custom = programs.filter { !$0.isBuiltIn }
            if !custom.isEmpty {
                Section("Мої програми") {
                    ForEach(custom) { program in
                        row(program)
                            .swipeActions {
                                if program.id != activeID {
                                    Button("Видалити", role: .destructive) { programToDelete = program }
                                }
                            }
                    }
                }
            }
            Section {
                Button {
                    showCreate = true
                } label: {
                    Label("Створити нову програму", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Програми")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") { dismiss() }
            }
        }
        .alert("Нова програма", isPresented: $showCreate) {
            TextField("Назва", text: $newName)
            Button("Створити") { create() }
            Button("Скасувати", role: .cancel) {}
        } message: {
            Text("Буде створено \(newDays) порожні дні - додай у них вправи.")
        }
        .confirmationDialog("Видалити програму?", isPresented: Binding(get: { programToDelete != nil }, set: { if !$0 { programToDelete = nil } }), titleVisibility: .visible) {
            Button("Видалити", role: .destructive) {
                if let programToDelete {
                    context.delete(programToDelete)
                    try? context.save()
                }
                programToDelete = nil
            }
        } message: {
            Text("Історія тренувань збережеться.")
        }
        .onAppear {
            newDays = max(1, profiles.first?.trainingWeekdays.count ?? 3)
        }
    }

    private func row(_ program: Program) -> some View {
        Button {
            ProgramStore.activate(program, context: context)
            Haptics.selection()
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name).font(.headline).foregroundStyle(.primary)
                    Text(program.summary.isEmpty ? String(localized: "\(program.days.count) дні") : program.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if program.id == activeID {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                        .accessibilityLabel(Text("Активна"))
                }
            }
        }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let program = ProgramStore.createProgram(name: name.isEmpty ? String(localized: "Моя програма") : name, days: newDays, context: context)
        ProgramStore.activate(program, context: context)
        newName = ""
        dismiss()
    }
}
