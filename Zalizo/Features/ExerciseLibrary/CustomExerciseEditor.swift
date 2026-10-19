import PhotosUI
import SwiftData
import SwiftUI
import ZalizoCore

/// Adds the user's own exercise (with an optional photo from the gallery).
struct CustomExerciseEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var nameEn = ""
    @State private var primary: Set<MuscleGroup> = []
    @State private var secondary: Set<MuscleGroup> = []
    @State private var equipment: Set<Equipment> = []
    @State private var mechanic: ExerciseMechanic = .compound
    @State private var region: BodyRegion = .upper
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !primary.isEmpty
    }

    var body: some View {
        Form {
            Section("Назва") {
                TextField("Наприклад: Жим у Смітті", text: $name)
                TextField("Англійська назва (необов'язково)", text: $nameEn)
                    .textInputAutocapitalization(.words)
            }
            .glassRows()
            Section("Основні м'язи") {
                muscleChips(selection: $primary)
            }
            .glassRows()
            Section("Допоміжні м'язи") {
                muscleChips(selection: $secondary)
            }
            .glassRows()
            Section("Обладнання") {
                FlowLayout {
                    ForEach(Equipment.allCases, id: \.self) { item in
                        ChipToggle(title: item.title, isOn: equipment.contains(item)) {
                            toggle(item, in: &equipment)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            .glassRows()
            Section("Тип") {
                Picker("Тип вправи", selection: $mechanic) {
                    ForEach(ExerciseMechanic.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Частина тіла", selection: $region) {
                    ForEach(BodyRegion.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            .glassRows()
            Section {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            } header: {
                Text("Техніка")
            } footer: {
                Text("Кожен крок - з нового рядка.")
            }
            .glassRows()
            Section("Фото") {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .grayscale(1)
                        .colorMultiply(Theme.Palette.ice)
                        .frame(maxHeight: 200)
                        .clipShape(.rect(cornerRadius: Theme.Radius.control))
                        .frame(maxWidth: .infinity)
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "photo", tint: Theme.Palette.accent)
                        Text(photoData == nil ? LocalizedStringResource("Обрати з галереї") : LocalizedStringResource("Обрати інше"))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .glassRows()
        }
        .zalScreen()
        .navigationTitle("Нова вправа")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Скасувати") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Зберегти") { save() }
                    .bold()
                    .disabled(!canSave)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { photoData = try? await item.loadTransferable(type: Data.self) }
        }
        .alert("Помилка", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func muscleChips(selection: Binding<Set<MuscleGroup>>) -> some View {
        FlowLayout {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                ChipToggle(title: group.title, isOn: selection.wrappedValue.contains(group)) {
                    toggle(group, in: &selection.wrappedValue)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func toggle<T: Hashable>(_ item: T, in set: inout Set<T>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }

    private func save() {
        let slug = "custom-\(UUID().uuidString.prefix(8).lowercased())"
        let exercise = Exercise(slug: slug, nameUk: name.trimmingCharacters(in: .whitespaces))
        exercise.nameEn = nameEn.trimmingCharacters(in: .whitespaces)
        exercise.primaryMusclesRaw = MuscleGroup.allCases.filter(primary.contains).map(\.rawValue)
        exercise.secondaryMusclesRaw = MuscleGroup.allCases.filter { secondary.contains($0) && !primary.contains($0) }.map(\.rawValue)
        let chosenEquipment = equipment.isEmpty ? [Equipment.bodyweight] : Equipment.allCases.filter(equipment.contains)
        exercise.equipmentRaw = chosenEquipment.map(\.rawValue)
        exercise.mechanicRaw = mechanic.rawValue
        exercise.regionRaw = region.rawValue
        exercise.progressionRaw = (chosenEquipment == [.bodyweight] ? ProgressionType.bodyweight : .doubleProgression).rawValue
        exercise.techniqueSteps = notes.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        exercise.isCustom = true
        exercise.userModified = true
        do {
            if let photoData {
                exercise.customImageFileName = try PhotoStorage.save(photoData, in: .exercisePhotos)
            }
            context.insert(exercise)
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
