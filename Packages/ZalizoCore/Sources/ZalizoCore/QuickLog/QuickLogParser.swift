import Foundation

/// Parses free text like "жим лежачи 70х10", "жим 70 кг 10 раз", "присід 100 на 5 × 3", "підтягування 12".
public enum QuickLogParser {
    public struct Candidate: Sendable {
        public let slug: String
        public let names: [String]

        public init(slug: String, names: [String]) {
            self.slug = slug
            self.names = names
        }
    }

    public struct Result: Equatable, Sendable {
        /// Best matching exercise (nil if nothing looks similar).
        public let slug: String?
        /// 0…1 match confidence.
        public let confidence: Double
        /// Other plausible exercises, best first.
        public let alternatives: [String]
        public let weight: Double?
        public let reps: Int?
        public let sets: Int
        /// The exercise part of the text.
        public let exerciseText: String
    }

    // MARK: Parsing numbers

    private static let unitWords: Set<String> = ["кг", "kg", "кіло", "кілограм", "кілограмів"]
    private static let repWords: Set<String> = ["раз", "рази", "разів", "повт", "повтори", "повторів", "повтор", "reps", "rep", "р"]
    private static let setWords: Set<String> = ["підх", "підходи", "підходів", "підхід", "сет", "сети", "sets", "set"]
    private static let fillerWords: Set<String> = ["на", "по", "з", "із", "x", "х", "×", "*", "by"]

    public static func parse(_ text: String, candidates: [Candidate]) -> Result {
        let normalized = SearchText.normalize(text)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "×", with: " x ")
            .replacingOccurrences(of: "*", with: " x ")
        var weight: Double?
        var reps: Int?
        var sets = 1
        var nameTokens: [String] = []

        // "70х10х3", "70x10", "100х5" - Latin/Cyrillic x between numbers.
        let compact = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*[xх]\s*(\d+)(?:\s*[xх]\s*(\d+))?"#)
        var remainder = normalized
        if let compact, let match = compact.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) {
            weight = number(match, 1, in: normalized)
            reps = number(match, 2, in: normalized).map { Int($0) }
            if let setCount = number(match, 3, in: normalized) { sets = max(1, Int(setCount)) }
            if let range = Range(match.range, in: normalized) {
                remainder.replaceSubrange(range, with: " ")
            }
        }

        let tokens = split(remainder)
        var numbers: [(value: Double, next: String?, previous: String?)] = []
        for (index, token) in tokens.enumerated() {
            if let value = Double(token) {
                numbers.append((value, index + 1 < tokens.count ? tokens[index + 1] : nil, index > 0 ? tokens[index - 1] : nil))
            } else if !unitWords.contains(token), !repWords.contains(token), !setWords.contains(token), !fillerWords.contains(token) {
                nameTokens.append(token)
            }
        }

        // Numbers with explicit units first.
        var unassigned: [Double] = []
        for item in numbers {
            if let next = item.next, unitWords.contains(next) { weight = weight ?? item.value }
            else if let next = item.next, repWords.contains(next) { reps = reps ?? Int(item.value) }
            else if let next = item.next, setWords.contains(next) { sets = max(1, Int(item.value)) }
            else if let previous = item.previous, setWords.contains(previous) { sets = max(1, Int(item.value)) }
            else { unassigned.append(item.value) }
        }
        // "жим 70 10" → weight then reps; a single bare number is reps ("підтягування 12") unless fractional.
        if weight == nil, reps == nil {
            if unassigned.count >= 2 {
                weight = unassigned[0]
                reps = Int(unassigned[1])
                if unassigned.count >= 3 { sets = max(1, Int(unassigned[2])) }
            } else if let single = unassigned.first {
                if single.truncatingRemainder(dividingBy: 1) != 0 { weight = single } else { reps = Int(single) }
            }
        } else if weight == nil, let first = unassigned.first {
            weight = first
        } else if reps == nil, let first = unassigned.first {
            reps = Int(first)
        }

        let exerciseText = nameTokens.joined(separator: " ")
        let ranked = rank(exerciseText, candidates: candidates)
        let best = ranked.first
        return Result(
            slug: best.flatMap { $0.score >= 0.34 ? $0.slug : nil },
            confidence: best?.score ?? 0,
            alternatives: ranked.dropFirst().prefix(4).filter { $0.score >= 0.25 }.map(\.slug),
            weight: weight,
            reps: reps,
            sets: sets,
            exerciseText: exerciseText
        )
    }

    private static func number(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> Double? {
        guard match.range(at: index).location != NSNotFound, let range = Range(match.range(at: index), in: text) else { return nil }
        return Double(text[range])
    }

    private static func split(_ text: String) -> [String] {
        // Separate glued units: "70кг" → "70 кг", "10раз" → "10 раз".
        var spaced = ""
        var previous: Character?
        for character in text {
            if let previous, (previous.isNumber && character.isLetter) || (previous.isLetter && character.isNumber) {
                spaced.append(" ")
            }
            spaced.append(character)
            previous = character
        }
        return spaced.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    // MARK: Fuzzy matching

    /// Scores candidates 0…1 by best matching name: token prefix overlap, with typo tolerance.
    public static func rank(_ query: String, candidates: [Candidate]) -> [(slug: String, score: Double)] {
        let queryTokens = SearchText.normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !queryTokens.isEmpty else { return [] }
        return candidates
            .map { candidate in
                let score = candidate.names.map { similarity(queryTokens, SearchText.normalize($0)) }.max() ?? 0
                return (candidate.slug, score)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
    }

    static func similarity(_ queryTokens: [String], _ name: String) -> Double {
        let nameTokens = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "(" || $0 == ")" }).map(String.init)
        guard !nameTokens.isEmpty else { return 0 }
        var matched = 0.0
        for token in queryTokens {
            let best = nameTokens.map { tokenScore(token, $0) }.max() ?? 0
            matched += best
        }
        let coverage = matched / Double(queryTokens.count)
        // Prefer names that are mostly covered by the query (short exact names win over long ones).
        let precision = min(1, matched / Double(nameTokens.count))
        return coverage * 0.75 + precision * 0.25
    }

    static func tokenScore(_ query: String, _ word: String) -> Double {
        if query == word { return 1 }
        // Ukrainian inflection/abbreviation: "присід" ~ "присідання", "лежачи" ~ "лежачи".
        let stemLength = min(query.count, word.count, 5)
        if stemLength >= 3, query.prefix(stemLength) == word.prefix(stemLength) { return 0.9 }
        if query.count >= 3, word.hasPrefix(query) { return 0.85 }
        if query.count >= 4 {
            let distance = levenshtein(query, String(word.prefix(query.count + 1)))
            if distance <= 1 { return 0.75 }
            if distance == 2, query.count >= 6 { return 0.55 }
        }
        return 0
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for (i, charA) in a.enumerated() {
            var current = [i + 1]
            for (j, charB) in b.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (charA == charB ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }
}
