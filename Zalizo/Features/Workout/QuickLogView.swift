import SwiftData
import SwiftUI
import ZalizoCore

/// "Швидкий запис": type "жим лежачи 70х10", confirm what was recognised, save as a finished workout (can be back-dated).
struct QuickLogView: View {
    struct Line: Identifiable {
        let id = UUID()
        var slug: String
        var name: String
        var weight: Double
        var reps: Int
        var sets: Int
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.nameUk) private var exercises: [Exercise]
    @State private var date = Date.now
    @State private var text = ""
    @State private var draft: Line?
    @State private var alternatives: [String] = []
    @State private var notRecognised = false
    @State private var lines: [Line] = []
    @State private var showLibrary = false
    @FocusState private var focused: Bool

    private var candidates: [QuickLogParser.Candidate] {
        exercises.map { QuickLogParser.Candidate(slug: $0.slug, names: [$0.nameUk, $0.nameEn] + $0.synonyms) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Коли", selection: $date, in: ...Date.now)
                }
                .glassRows()
                Section {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(systemImage: "text.cursor", tint: Theme.Palette.accent, size: 34)
                        TextField("Наприклад: жим лежачи 70х10", text: $text)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit { parse() }
                            .autocorrectionDisabled()
                    }
                    Button("Розпізнати") { parse() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                } footer: {
                    Text("Формати: «присід 100 на 5», «жим 70 кг 10 раз», «тяга 60х8х3» (3 підходи).")
                }
                .glassRows()

                if notRecognised {
                    Section {
                        Label("Не вдалося впізнати вправу - обери її вручну.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.Palette.warning)
                        Button("Обрати з бібліотеки") { showLibrary = true }
                    }
                    .glassRows()
                }

                if let draft {
                    Section("Розпізнано") {
                        Menu {
                            ForEach(alternatives, id: \.self) { slug in
                                Button(name(slug)) { self.draft?.slug = slug; self.draft?.name = name(slug) }
                            }
                            Button("Інша вправа…") { showLibrary = true }
                        } label: {
                            LabeledContent("Вправа") { Text(draft.name).foregroundStyle(.primary) }
                        }
                        Stepper(value: Binding(get: { draft.weight }, set: { self.draft?.weight = max(0, $0) }), in: 0...500, step: 2.5) {
                            LabeledContent("Вага") { Text("\(draft.weight.preciseText) кг").monospacedDigit() }
                        }
                        Stepper(value: Binding(get: { draft.reps }, set: { self.draft?.reps = $0 }), in: 1...100) {
                            LabeledContent("Повтори") { Text("\(draft.reps)").monospacedDigit() }
                        }
                        Stepper(value: Binding(get: { draft.sets }, set: { self.draft?.sets = $0 }), in: 1...10) {
                            LabeledContent("Підходи") { Text("\(draft.sets)").monospacedDigit() }
                        }
                        Button {
                            lines.append(draft)
                            self.draft = nil
                            text = ""
                            focused = true
                        } label: {
                            Label("Додати", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                        }
                    }
                    .glassRows()
                }

                if !lines.isEmpty {
                    Section("Записано") {
                        ForEach(lines) { line in
                            HStack(spacing: Theme.Spacing.m) {
                                GlowDot(size: 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.name)
                                    Text("\(line.weight.preciseText) кг × \(line.reps) × \(line.sets)")
                                        .font(.subheadline.weight(.light).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { lines.remove(atOffsets: $0) }
                    }
                    .glassRows()
                }
            }
            .zalScreen()
            .navigationTitle("Швидкий запис")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Зберегти") { save() }
                        .bold()
                        .disabled(lines.isEmpty)
                }
            }
            .sheet(isPresented: $showLibrary) {
                NavigationStack {
                    ExerciseLibraryView { exercise in
                        if draft == nil {
                            let result = QuickLogParser.parse(text, candidates: candidates)
                            draft = Line(slug: exercise.slug, name: exercise.nameUk, weight: result.weight ?? 0, reps: result.reps ?? 10, sets: result.sets)
                        } else {
                            draft?.slug = exercise.slug
                            draft?.name = exercise.nameUk
                        }
                        notRecognised = false
                        showLibrary = false
                    }
                }
            }
            .onAppear { focused = true }
        }
    }

    private func name(_ slug: String) -> String {
        exercises.first { $0.slug == slug }?.nameUk ?? slug
    }

    private func parse() {
        let result = QuickLogParser.parse(text, candidates: candidates)
        alternatives = result.alternatives
        guard let slug = result.slug else {
            draft = nil
            notRecognised = true
            return
        }
        notRecognised = false
        alternatives = [slug] + result.alternatives
        draft = Line(slug: slug, name: name(slug), weight: result.weight ?? 0, reps: result.reps ?? 10, sets: result.sets)
    }

    private func save() {
        let session = WorkoutService.startEmpty(title: String(localized: "Швидкий запис"), startedAt: date, in: context)
        for (index, line) in lines.enumerated() {
            let performed = PerformedExercise(order: index, exerciseSlug: line.slug, exerciseName: line.name)
            performed.plannedSets = line.sets
            performed.repMin = line.reps
            performed.repMax = line.reps
            performed.sets = (0..<line.sets).map { order in
                let set = SetEntry(order: order, weightKg: line.weight, reps: line.reps)
                set.isCompleted = true
                set.completedAt = date
                return set
            }
            session.exercises.append(performed)
        }
        let minutes = lines.reduce(0) { $0 + $1.sets } * 3
        session.endedAt = date.addingTimeInterval(TimeInterval(minutes * 60))
        WorkoutService.finish(session, feeling: nil, note: "", at: date, in: context)
        AchievementService.evaluate(in: context)
        Haptics.setCompleted()
        dismiss()
    }
}
