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
    @State private var imageIndex = 0

    private var alternatives: [Exercise] {
        exercise.alternatives.compactMap { slug in allExercises.first { $0.slug == slug } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                hero
                tags
                musclesCard
                if !exercise.techniqueSteps.isEmpty {
                    DetailSection(title: "Техніка", systemImage: "list.number") {
                        ForEach(Array(exercise.techniqueSteps.enumerated()), id: \.offset) { index, step in
                            StepRow(number: index + 1, text: step)
                        }
                    }
                }
                if !exercise.commonMistakes.isEmpty {
                    DetailSection(title: "Типові помилки", systemImage: "exclamationmark.triangle", tint: Theme.Palette.warning) {
                        BulletList(items: exercise.commonMistakes, symbol: "exclamationmark", color: Theme.Palette.warning)
                    }
                }
                if !exercise.safetyTips.isEmpty || !exercise.riskAreas.isEmpty {
                    DetailSection(title: "Безпека", systemImage: "shield.lefthalf.filled") {
                        BulletList(items: exercise.safetyTips, symbol: "checkmark", color: Theme.Palette.success)
                        if !exercise.riskAreas.isEmpty {
                            Text("Навантажує: \(riskAreasText). Якщо є обмеження - обери альтернативу.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !exercise.breathing.isEmpty {
                    DetailSection(title: "Дихання", systemImage: "wind", tint: Theme.Palette.blue) {
                        Text(exercise.breathing)
                    }
                }
                if !alternatives.isEmpty {
                    DetailSection(title: "Альтернативи", systemImage: "arrow.triangle.swap") {
                        ForEach(alternatives) { alternative in
                            NavigationLink {
                                ExerciseDetailView(exercise: alternative)
                            } label: {
                                HStack(spacing: Theme.Spacing.s) {
                                    ExerciseRow(exercise: alternative)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            if alternative.id != alternatives.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                photoControls
                if exercise.isCustom {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Видалити вправу", systemImage: "trash")
                            .foregroundStyle(Theme.Palette.danger)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .zalScreen()
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
                .tint(Theme.Palette.accent)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .onChange(of: exercise.customImageFileName) { _, _ in
            imageIndex = 0
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

    /// "Поперек, Коліна" (kept out of the Text interpolation for the type checker).
    private var riskAreasText: String {
        exercise.riskAreas.map { String(localized: $0.title) }.joined(separator: ", ")
    }

    private var imageCount: Int {
        exercise.customImageFileName != nil ? 1 : max(1, exercise.imageNames.count)
    }

    /// Big monochrome photo card: start/finish pages, name at the bottom.
    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
        return TabView(selection: $imageIndex) {
            ForEach(0..<imageCount, id: \.self) { index in
                Color.clear
                    .overlay { ExerciseImage(exercise: exercise, index: index) }
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 320)
        .overlay {
            LinearGradient(
                colors: [.clear, Theme.Palette.canvasBottom.opacity(0.35), Theme.Palette.canvasBottom.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if !exercise.nameEn.isEmpty {
                    Text(exercise.nameEn).eyebrow()
                }
                Text(exercise.nameUk)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(3)
            }
            .padding(Theme.Spacing.xl)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if imageCount > 1 {
                phaseSwitcher.padding(Theme.Spacing.m)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    /// "Початок / Кінець" pills over the photo.
    private var phaseSwitcher: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ChipToggle(title: "Початок", isOn: imageIndex == 0) {
                withAnimation(.snappy) { imageIndex = 0 }
            }
            ChipToggle(title: "Кінець", isOn: imageIndex == 1) {
                withAnimation(.snappy) { imageIndex = 1 }
            }
        }
        .padding(Theme.Spacing.xs)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var tags: some View {
        FlowLayout {
            TagView(text: String(localized: exercise.mechanic.title))
            TagView(text: String(localized: exercise.level.title))
            ForEach(exercise.equipment, id: \.self) { item in
                TagView(text: String(localized: item.title))
            }
        }
    }

    /// Muscle pills (primary lime, secondary blue) and the body map.
    private var musclesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Задіяні м'язи").eyebrow()
            FlowLayout {
                ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                    TagView(text: String(localized: muscle.title), tint: Theme.Palette.accent)
                }
                ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                    TagView(text: String(localized: muscle.title), tint: Theme.Palette.blue)
                }
            }
            BodyMapView(primary: exercise.primaryMuscles, secondary: exercise.secondaryMuscles)
                .frame(height: 220)
                .padding(.top, Theme.Spacing.s)
            HStack(spacing: Theme.Spacing.l) {
                legend(Theme.Palette.accent, "основні")
                legend(Theme.Palette.blue, "допоміжні")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        }
        .cardStyle()
    }

    private func legend(_ color: Color, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            GlowDot(color: color, size: 7)
            Text(text)
        }
    }

    private var photoControls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: Theme.Spacing.m) {
                    IconBadge(systemImage: "photo.on.rectangle", tint: Theme.Palette.accent)
                    Text(exercise.customImageFileName == nil ? LocalizedStringResource("Замінити фото своїм") : LocalizedStringResource("Обрати інше фото"))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
            }
            if exercise.customImageFileName != nil, !exercise.imageNames.isEmpty {
                Button {
                    removeCustomPhoto()
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "arrow.uturn.backward")
                        Text("Повернути стандартні фото").foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
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
    var tint: Color = Theme.Palette.accent
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: systemImage, tint: tint, size: 34)
                Text(title).font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content
        }
        .cardStyle()
    }
}

/// Technique step with a glowing lime number.
private struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text("\(number)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 26, height: 26)
                .background(Theme.Palette.accent, in: Circle())
                .shadow(color: Theme.Palette.accent.opacity(0.5), radius: 6)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BulletList: View {
    let items: [String]
    let symbol: String
    let color: Color

    var body: some View {
        ForEach(items, id: \.self) { item in
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.15), in: Circle())
                Text(item)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Capsule tag; tinted tags are used for muscles.
struct TagView: View {
    let text: String
    var tint: Color?

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint ?? Color.primary)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 6)
            .background((tint ?? Color.white).opacity(tint == nil ? 0.07 : 0.14), in: Capsule())
            .overlay { Capsule().strokeBorder((tint ?? Color.white).opacity(tint == nil ? 0.12 : 0.35), lineWidth: 1) }
    }
}
