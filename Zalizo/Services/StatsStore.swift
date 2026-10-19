import Foundation
import SwiftData
import ZalizoCore

/// Converts SwiftData rows into the value types used by `StatsService` / `WeightTrend`.
@MainActor
enum StatsStore {
    static func records(_ sessions: [WorkoutSession], exercises: [Exercise]) -> [SessionRecord] {
        let bySlug = Dictionary(exercises.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        return sessions.filter(\.isFinished).map { session in
            SessionRecord(
                date: session.startedAt,
                durationSeconds: Int(session.duration),
                exercises: session.orderedExercises.compactMap { performed in
                    let sets = performed.workingSets.map { PerformedSet(weight: $0.weightKg, reps: $0.reps, rir: $0.rir) }
                    guard !sets.isEmpty else { return nil }
                    let exercise = bySlug[performed.exerciseSlug]
                    return SessionRecord.Exercise(
                        slug: performed.exerciseSlug,
                        primary: exercise?.primaryMuscles ?? [],
                        secondary: exercise?.secondaryMuscles ?? [],
                        sets: sets
                    )
                }
            )
        }
    }

    static func weightSamples(_ entries: [BodyWeightEntry]) -> [WeightSample] {
        entries.map { WeightSample(date: $0.date, weightKg: $0.weightKg) }
    }
}

extension StatsPeriod {
    var title: LocalizedStringResource {
        switch self {
        case .fourWeeks: "4 тиж"
        case .threeMonths: "3 міс"
        case .sixMonths: "6 міс"
        case .year: "Рік"
        case .all: "Усе"
        }
    }
}
