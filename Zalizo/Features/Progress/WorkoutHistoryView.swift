import SwiftData
import SwiftUI
import ZalizoCore

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    var body: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView("Ще немає тренувань", systemImage: "clock.arrow.circlepath")
            }
            ForEach(sessions) { session in
                NavigationLink {
                    WorkoutDetailView(session: session)
                } label: {
                    let stats = WorkoutService.stats(for: session)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title).font(.headline)
                        Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(stats.durationSeconds / 60) хв · \(Int(stats.tonnage).groupedText) кг")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { sessions[$0] }.forEach(context.delete)
                try? context.save()
            }
        }
        .navigationTitle("Історія тренувань")
    }
}

struct WorkoutDetailView: View {
    let session: WorkoutSession

    var body: some View {
        let stats = WorkoutService.stats(for: session)
        List {
            Section {
                LabeledContent("Дата", value: session.startedAt.formatted(date: .long, time: .shortened))
                LabeledContent("Тривалість", value: String(localized: "\(stats.durationSeconds / 60) хв"))
                LabeledContent("Тоннаж", value: String(localized: "\(Int(stats.tonnage).groupedText) кг"))
                LabeledContent("Робочих підходів", value: "\(stats.workingSets)")
                if let feeling = session.feeling {
                    LabeledContent {
                        Text(FeelingText.title(feeling))
                    } label: {
                        Text("Самопочуття")
                    }
                }
                if session.isDeload {
                    Label("Розвантажувальне тренування", systemImage: "leaf")
                }
                if !session.note.isEmpty {
                    Text(session.note)
                }
            }
            ForEach(session.orderedExercises.filter { !$0.workingSets.isEmpty }) { performed in
                Section(performed.exerciseName) {
                    ForEach(Array(performed.workingSets.enumerated()), id: \.element.id) { index, set in
                        LabeledContent {
                            Text("\(set.weightKg.preciseText) кг × \(set.reps)\(set.rir.map { " · RIR \($0)" } ?? "")").monospacedDigit()
                        } label: {
                            Text("Підхід \(index + 1)")
                        }
                    }
                }
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
