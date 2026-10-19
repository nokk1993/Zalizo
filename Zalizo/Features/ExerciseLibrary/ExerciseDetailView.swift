import PhotosUI
import SwiftData
import SwiftUI
import ZalizoCore

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]
    @State private var photoItem: PhotosPickerItem?
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    private var alternatives: [Exercise] {
        exercise.alternatives.compactMap { slug in allExercises.first { $0.slug == slug } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                imagePager
                header
                BodyMapView(primary: exercise.primaryMuscles, secondary: exercise.secondaryMuscles)
                    .frame(height: 220)
                    .cardStyle()

                if !exercise.techniqueSteps.isEmpty {
                    DetailSection(title: "Техніка", systemImage: "list.number") {
                        ForEach(Array(exercise.techniqueSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                                Text("\(index + 1)")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 20, alignment: .trailing)
                                Text(step)
                            }
                        }
                    }
                }
                if !exercise.commonMistakes.isEmpty {
                    DetailSection(title: "Типові помилки", systemImage: "exclamationmark.triangle") {
                        BulletList(items: exercise.commonMistakes, symbol: "xmark", color: Theme.Palette.danger)
                    }
                }
                if !exercise.safetyTips.isEmpty || !exercise.riskAreas.isEmpty {
                    DetailSection(title: "Безпека", systemImage: "shield.lefthalf.filled") {
                        BulletList(items: exercise.safetyTips, symbol: "checkmark", color: Theme.Palette.success)
                        if !exercise.riskAreas.isEmpty {
                            Text("Навантажує: \(exercise.riskAreas.map { String(localized: $0.title) }.joined(separator: ", ")). Якщо є обмеження - обери альтернативу.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !exercise.breathing.isEmpty {
                    DetailSection(title: "Дихання", systemImage: "wind") {
                        Text(exercise.breathing)
                    }
                }
                if !alternatives.isEmpty {
                    DetailSection(title: "Альтернативи", systemImage: "arrow.triangle.swap") {
                        ForEach(alternatives) { alternative in
                            NavigationLink {
                                ExerciseDetailView(exercise: alternative)
                            } label: {
                                ExerciseRow(exercise: alternative)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                photoControls
                if exercise.isCustom {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Видалити вправу", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .navigationTitle(exercise.nameUk)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exercise.isFavorite.toggle()
                    Haptics.selection()
                } label: {
                    if exercise.isFavorite {
                        Label("Прибрати з обраного", systemImage: "star.fill")
                    } else {
                        Label("В обране", systemImage: "star")
                    }
                }
                .tint(.yellow)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .confirmationDialog("Видалити вправу?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Видалити", role: .destructive) { deleteExercise() }
        } message: {
            Text("Історія тренувань з цією вправою збережеться.")
        }
        .alert("Помилка", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var imagePager: some View {
        let count = exercise.customImageFileName != nil ? 1 : max(1, exercise.imageNames.count)
        return TabView {
            ForEach(0..<count, id: \.self) { index in
                ExerciseImage(exercise: exercise, index: index)
                    .overlay(alignment: .bottomLeading) {
                        if count > 1 {
                            Text(index == 0 ? LocalizedStringResource("Початок") : LocalizedStringResource("Кінець"))
                                .font(.caption.bold())
                                .padding(.horizontal, Theme.Spacing.s)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(Theme.Spacing.s)
                        }
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: count > 1 ? .always : .never))
        .frame(height: 240)
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(exercise.nameUk).font(.title2.bold())
            if !exercise.nameEn.isEmpty {
                Text(exercise.nameEn).font(.subheadline).foregroundStyle(.secondary)
            }
            FlowLayout {
                TagView(text: String(localized: exercise.mechanic.title))
                TagView(text: String(localized: exercise.level.title))
                ForEach(exercise.equipment, id: \.self) { item in
                    TagView(text: String(localized: item.title))
                }
            }
            Text(exercise.musclesSummary).font(.subheadline)
        }
    }

    private var photoControls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(exercise.customImageFileName == nil ? LocalizedStringResource("Замінити фото своїм") : LocalizedStringResource("Обрати інше фото"), systemImage: "photo.on.rectangle")
            }
            if exercise.customImageFileName != nil, !exercise.imageNames.isEmpty {
                Button {
                    removeCustomPhoto()
                } label: {
                    Label("Повернути стандартні фото", systemImage: "arrow.uturn.backward")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let name = try PhotoStorage.save(data, in: .exercisePhotos)
            if let old = exercise.customImageFileName {
                PhotoStorage.delete(old, in: .exercisePhotos)
            }
            exercise.customImageFileName = name
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        photoItem = nil
    }

    private func removeCustomPhoto() {
        if let old = exercise.customImageFileName {
            PhotoStorage.delete(old, in: .exercisePhotos)
        }
        exercise.customImageFileName = nil
        try? context.save()
    }

    private func deleteExercise() {
        if let file = exercise.customImageFileName {
            PhotoStorage.delete(file, in: .exercisePhotos)
        }
        context.delete(exercise)
        try? context.save()
        dismiss()
    }
}

struct DetailSection<Content: View>: View {
    let title: LocalizedStringResource
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label { Text(title) } icon: { Image(systemName: systemImage) }
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BulletList: View {
    let items: [String]
    let symbol: String
    let color: Color

    var body: some View {
        ForEach(items, id: \.self) { item in
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Image(systemName: symbol)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Text(item)
            }
        }
    }
}

struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.secondary.opacity(0.15), in: .capsule)
    }
}
