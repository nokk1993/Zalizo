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
            Section {
                ForEach(programs.filter(\.isBuiltIn)) { program in
                    row(program)
                }
            } header: {
                SectionHeader("Вбудовані")
                    .textCase(nil)
                    .foregroundStyle(.primary)
            }
            let custom = programs.filter { !$0.isBuiltIn }
            if !custom.isEmpty {
                Section {
                    ForEach(custom) { program in
                        row(program)
                            .swipeActions {
                                if program.id != activeID {
                                    Button("Видалити", role: .destructive) { programToDelete = program }
                                }
                            }
                    }
                } header: {
                    SectionHeader("Мої програми")
                        .textCase(nil)
                        .foregroundStyle(.primary)
                }
            }
            Section {
                Button {
                    showCreate = true
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "plus", tint: Theme.Palette.accent)
                        Text("Створити нову програму").foregroundStyle(.primary)
                    }
                }
            }
            .glassRows()
        }
        .zalScreen()
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
            ProgramOptionCard(program: program, isActive: program.id == activeID)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let program = ProgramStore.createProgram(name: name.isEmpty ? String(localized: "Моя програма") : name, days: newDays, context: context)
        ProgramStore.activate(program, context: context)
        newName = ""
        dismiss()
    }
}

/// Glass card of a program; the active one glows lime.
private struct ProgramOptionCard: View {
    let program: Program
    let isActive: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(program.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(program.summary.isEmpty ? String(localized: "\(program.days.count) дні") : program.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    GlowDot(color: isActive ? Theme.Palette.accent : Theme.Palette.textTertiary, size: 6)
                    Text("\(program.days.count) дн. у циклі")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(isActive ? 0 : 0.25), lineWidth: 1.5)
                if isActive {
                    Circle().fill(Theme.Palette.accent)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.Palette.onAccent)
                }
            }
            .frame(width: 26, height: 26)
            .shadow(color: Theme.Palette.accent.opacity(isActive ? 0.6 : 0), radius: 8)
            .accessibilityHidden(true)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { GlassSurface(tint: isActive ? Theme.Palette.accent : nil) }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(isActive ? Theme.Palette.accent.opacity(0.9) : .clear, lineWidth: 1.5)
        }
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
