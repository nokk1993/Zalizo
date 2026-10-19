import Foundation
import Testing
@testable import ZalizoCore

@Suite("Quick log parser")
struct QuickLogParserTests {
    var candidates: [QuickLogParser.Candidate] {
        get throws {
            try SeedFiles.exercises().exercises.map { QuickLogParser.Candidate(slug: $0.slug, names: [$0.nameUk, $0.nameEn] + $0.synonyms) }
        }
    }

    struct Case: Sendable, CustomTestStringConvertible {
        let text: String
        let slug: String
        let weight: Double?
        let reps: Int?
        var sets = 1
        var testDescription: String { text }
    }

    static let cases: [Case] = [
        Case(text: "жим лежачи 70х10", slug: "barbell-bench-press", weight: 70, reps: 10),
        Case(text: "жим 70 кг 10 раз", slug: "barbell-bench-press", weight: 70, reps: 10),
        Case(text: "Жим лежачи 72,5 × 8", slug: "barbell-bench-press", weight: 72.5, reps: 8),
        Case(text: "жим лежачи 70x10x3", slug: "barbell-bench-press", weight: 70, reps: 10, sets: 3),
        Case(text: "присід 100 на 5", slug: "barbell-back-squat", weight: 100, reps: 5),
        Case(text: "присідання 100кг 5 повторів 4 підходи", slug: "barbell-back-squat", weight: 100, reps: 5, sets: 4),
        Case(text: "підтягування 12", slug: "pull-up", weight: nil, reps: 12),
        Case(text: "румунська тяга 80*8", slug: "romanian-deadlift", weight: 80, reps: 8),
        Case(text: "bench 70x10", slug: "barbell-bench-press", weight: 70, reps: 10),
        Case(text: "молотки 14 кг 12 раз", slug: "hammer-curl", weight: 14, reps: 12),
        Case(text: "жим ногами 160 12", slug: "leg-press", weight: 160, reps: 12),
        Case(text: "армійський жим 40х8", slug: "overhead-press", weight: 40, reps: 8),
        Case(text: "тяга верхнього блока 55 кг 10", slug: "lat-pulldown", weight: 55, reps: 10),
        Case(text: "махи в сторони 10 15", slug: "dumbbell-lateral-raise", weight: 10, reps: 15),
        Case(text: "присидання 90 6", slug: "barbell-back-squat", weight: 90, reps: 6) // typo
    ]

    @Test("Parses phrases", arguments: cases)
    func parse(_ example: Case) throws {
        let result = QuickLogParser.parse(example.text, candidates: try candidates)
        #expect(result.slug == example.slug, "\(example.text) → \(result.slug ?? "nil") (\(result.confidence))")
        #expect(result.weight == example.weight)
        #expect(result.reps == example.reps)
        #expect(result.sets == example.sets)
    }

    @Test func unknownExercise() throws {
        let result = QuickLogParser.parse("йога 30", candidates: try candidates)
        #expect(result.slug == nil)
        #expect(result.reps == 30)
    }

    @Test func emptyText() throws {
        let result = QuickLogParser.parse("", candidates: try candidates)
        #expect(result.slug == nil)
        #expect(result.weight == nil && result.reps == nil)
    }

    @Test func levenshtein() {
        #expect(QuickLogParser.levenshtein("присід", "присід") == 0)
        #expect(QuickLogParser.levenshtein("жим", "жом") == 1)
        #expect(QuickLogParser.levenshtein("", "abc") == 3)
    }
}
