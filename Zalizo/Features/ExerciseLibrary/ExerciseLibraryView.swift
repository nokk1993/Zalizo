import SwiftData
import SwiftUI
import ZalizoCore

/// Exercise library: search, muscle/equipment filters, favourites.
/// With `onPick` it works as a picker (replace/add exercise) instead of opening details.
struct ExerciseLibraryView: View {
    var onPick: ((Exercise) -> Void)?

    @Query(sort: \Exercise.nameUk) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var muscle: MuscleGroup?
    @State private var equipment: Equipment?
    @State private var favoritesOnly = false
    @State private var showEditor = false

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            (muscle.map { exercise.primaryMuscles.contains($0) || exercise.secondaryMuscles.contains($0) } ?? true)
                && (equipment.map { exercise.equipment.contains($0) } ?? true)
                && (!favoritesOnly || exercise.isFavorite)
                && SearchText.matches(query: searchText, fields: [exercise.nameUk, exercise.nameEn] + exercise.synonyms)
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
            ForEach(filtered) { exercise in
                if let onPick {
                    Button {
                        onPick(exercise)
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: Text("Назва вправи"))
        .navigationTitle("Бібліотека вправ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
            if onPick == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Додати вправу", systemImage: "plus")
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if muscle != nil || equipment != nil || favoritesOnly {
                activeFilters
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { CustomExerciseEditor() }
        }
    }

    private var filterMenu: some View {
        Menu {
            Toggle(isOn: $favoritesOnly) {
                Label("Лише обрані", systemImage: "star")
            }
            Picker(selection: $muscle) {
                Text("Усі м'язи").tag(MuscleGroup?.none)
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    Text(group.title).tag(MuscleGroup?.some(group))
                }
            } label: {
                Label("Група м'язів", systemImage: "figure.arms.open")
            }
            .pickerStyle(.menu)
            Picker(selection: $equipment) {
                Text("Усе обладнання").tag(Equipment?.none)
                ForEach(Equipment.allCases, id: \.self) { item in
                    Text(item.title).tag(Equipment?.some(item))
                }
            } label: {
                Label("Обладнання", systemImage: "dumbbell")
            }
            .pickerStyle(.menu)
        } label: {
            Label("Фільтри", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                if favoritesOnly {
                    FilterChip(title: "Обрані") { favoritesOnly = false }
                }
                if let muscle {
                    FilterChip(title: muscle.title) { self.muscle = nil }
                }
                if let equipment {
                    FilterChip(title: equipment.title) { self.equipment = nil }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
        }
        .background(.bar)
    }
}

private struct FilterChip: View {
    let title: LocalizedStringResource
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(title)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.accentColor.opacity(0.15), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Прибрати фільтр"))
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ExerciseImage(exercise: exercise)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.nameUk)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(exercise.musclesSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if exercise.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(Text("Обрана"))
            }
        }
        .contentShape(.rect)
    }
}

extension Exercise {
    /// "Груди · Трицепс, Плечі"
    var musclesSummary: String {
        let primary = primaryMuscles.map { String(localized: $0.title) }.joined(separator: ", ")
        let secondary = secondaryMuscles.map { String(localized: $0.title) }.joined(separator: ", ")
        return secondary.isEmpty ? primary : "\(primary) · \(secondary)"
    }
}

#Preview {
    NavigationStack { ExerciseLibraryView() }
        .previewData()
}
