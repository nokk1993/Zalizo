import Foundation

public struct KnowledgeArticle: Codable, Equatable, Sendable, Identifiable {
    public enum Category: String, Codable, CaseIterable, Sendable {
        case training, nutrition, recovery, app
    }

    public var id: String
    public var category: Category
    public var title: String
    public var summary: String
    /// Markdown; paragraphs separated by blank lines.
    public var body: String

    public var paragraphs: [String] {
        body.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

public struct KnowledgeFile: Codable, Equatable, Sendable {
    public var version: Int
    public var articles: [KnowledgeArticle]

    public static func decode(_ data: Data) throws -> KnowledgeFile {
        try JSONDecoder().decode(KnowledgeFile.self, from: data)
    }
}
