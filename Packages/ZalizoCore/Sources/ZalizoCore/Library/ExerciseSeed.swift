import Foundation

/// Exercise definition as stored in `Resources/Seed/exercises.json`.
public struct ExerciseSeed: Codable, Equatable, Sendable {
    public var slug: String
    public var nameUk: String
    public var nameEn: String
    public var synonyms: [String]
    public var primaryMuscles: [MuscleGroup]
    public var secondaryMuscles: [MuscleGroup]
    public var equipment: [Equipment]
    public var mechanic: ExerciseMechanic
    public var level: ExerciseLevel
    public var region: BodyRegion
    public var progression: ProgressionType
    public var techniqueSteps: [String]
    public var commonMistakes: [String]
    public var safetyTips: [String]
    public var breathing: String
    public var alternatives: [String]
    public var riskAreas: [InjuryArea]
    public var imageNames: [String]
    /// Folder in free-exercise-db the images came from (attribution/debugging).
    public var source: String?
}

public struct ExerciseSeedFile: Codable, Equatable, Sendable {
    public var version: Int
    public var exercises: [ExerciseSeed]

    public static func decode(_ data: Data) throws -> ExerciseSeedFile {
        try JSONDecoder().decode(ExerciseSeedFile.self, from: data)
    }
}

/// Decides what to do with each seeded exercise on app start / update.
/// Seeds never overwrite exercises the user has edited.
public enum SeedMerge {
    public struct ExistingState: Equatable, Sendable {
        public let seedVersion: Int
        public let userModified: Bool

        public init(seedVersion: Int, userModified: Bool) {
            self.seedVersion = seedVersion
            self.userModified = userModified
        }
    }

    public enum Action: Equatable, Sendable {
        case insert(slug: String)
        case update(slug: String)
        case keepUserVersion(slug: String)
        case upToDate(slug: String)
    }

    public static func plan(seedVersion: Int, seedSlugs: [String], existing: [String: ExistingState]) -> [Action] {
        seedSlugs.map { slug in
            guard let state = existing[slug] else { return .insert(slug: slug) }
            if state.userModified { return .keepUserVersion(slug: slug) }
            if state.seedVersion >= seedVersion { return .upToDate(slug: slug) }
            return .update(slug: slug)
        }
    }
}

/// Text normalisation for search: lowercase, no diacritics, apostrophes unified, ё/є/ї folded.
public enum SearchText {
    public static func normalize(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "uk_UA"))
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "ʼ", with: "'")
            .replacingOccurrences(of: "`", with: "'")
        return folded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True if every word of the query is found in one of the fields.
    public static func matches(query: String, fields: [String]) -> Bool {
        let words = normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return true }
        let haystack = fields.map(normalize).joined(separator: " ")
        return words.allSatisfy { haystack.contains($0) }
    }
}
