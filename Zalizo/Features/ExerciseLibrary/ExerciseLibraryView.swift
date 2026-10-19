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
        exercises.filter { matchesFilters($0) }
    }

    /// Split into separate checks: one long `?? / && / +` chain is slow for the type checker.
    private func matchesFilters(_ exercise: Exercise) -> Bool {
        if let muscle, !exercise.primaryMuscles.contains(muscle), !exercise.secondaryMuscles.contains(muscle) {
            return false
        }
        if let equipment, !exercise.equipment.contains(equipment) {
            return false
        }
        if favoritesOnly, !exercise.isFavorite {
            return false
        }
        let fields: [String] = [exercise.nameUk, exercise.nameEn] + exercise.synonyms
        return SearchText.matches(query: searchText, fields: fields)
    }

    var body: some View {
        List {
            Section {
                filterPills
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.l, bottom: Theme.Spacing.s, trailing: Theme.Spacing.l))
            }
            Section {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ForEach(filtered) { exercise in
                    Group {
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
                    .listRowBackground(LibraryRowBackground())
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.s, leading: Theme.Spacing.l + Theme.Spacing.s, bottom: Theme.Spacing.s, trailing: Theme.Spacing.l + Theme.Spacing.s))
                }
            }
        }
        .listStyle(.plain)
        .zalScreen()
        .searchable(text: $searchText, prompt: Text("Назва вправи"))
        .navigationTitle("Бібліотека вправ")
        .toolbar {
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
        .sheet(isPresented: $showEditor) {
            NavigationStack { CustomExerciseEditor() }
        }
    }

    /// Two horizontal pill rows: muscle groups (+ favourites) and equipment.
    private var filterPills: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.s) {
                    ChipToggle(title: "Усі м'язи", isOn: muscle == nil && !favoritesOnly) {
                        withAnimation(.snappy) {
                            muscle = nil
                            favoritesOnly = false
                        }
                    }
                    ChipToggle(title: "★ Обрані", isOn: favoritesOnly) {
                        withAnimation(.snappy) { favoritesOnly.toggle() }
                    }
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        ChipToggle(title: group.title, isOn: muscle == group) {
                            withAnimation(.snappy) { muscle = muscle == group ? nil : group }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.s) {
                    ChipToggle(title: "Усе обладнання", isOn: equipment == nil) {
                        withAnimation(.snappy) { equipment = nil }
                    }
                    ForEach(Equipment.allCases, id: \.self) { item in
                        ChipToggle(title: item.title, isOn: equipment == item) {
                            withAnimation(.snappy) { equipment = equipment == item ? nil : item }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

/// Flat translucent rounded card behind a library row (no blur: long lists stay fast).
private struct LibraryRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Theme.Palette.row)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 3)
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ExerciseImage(exercise: exercise)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.nameUk)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(exercise.musclesSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if exercise.isFavorite {
                Image(systemName: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.accent)
                    .shadow(color: Theme.Palette.accent.opacity(0.6), radius: 4)
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
