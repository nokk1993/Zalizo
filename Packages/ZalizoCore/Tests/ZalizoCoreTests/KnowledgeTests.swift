import Foundation
import Testing
@testable import ZalizoCore

@Suite("Knowledge base")
struct KnowledgeTests {
    @Test func articlesCoverRequiredTopics() throws {
        let file = try KnowledgeFile.decode(Data(contentsOf: SeedFiles.url("Zalizo/Resources/Seed/knowledge.json")))
        let ids = Set(file.articles.map(\.id))
        for required in ["hypertrophy-basics", "double-progression", "safety", "warmup", "recovery-sleep",
                         "moving-average", "reading-charts", "plateau", "deload", "supplements"] {
            #expect(ids.contains(required), "\(required)")
        }
        for article in file.articles {
            #expect(!article.paragraphs.isEmpty)
            #expect(!article.title.isEmpty && !article.summary.isEmpty)
        }
        #expect(file.articles.contains { $0.category == .nutrition })
    }

    @Test func noDrugAdvice() throws {
        let file = try KnowledgeFile.decode(Data(contentsOf: SeedFiles.url("Zalizo/Resources/Seed/knowledge.json")))
        let text = file.articles.map(\.body).joined().lowercased()
        // Steroids are only mentioned as a warning, never with dosing.
        #expect(!text.contains("курс стероїд"))
        #expect(text.contains("проконсультуйся з лікарем") || text.contains("порадься з лікарем"))
    }
}
