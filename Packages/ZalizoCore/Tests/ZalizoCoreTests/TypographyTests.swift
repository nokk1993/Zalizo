import Foundation
import Testing

@Suite("Typography")
struct TypographyTests {
    /// Texts of the app use the short hyphen "-" only, never long dashes.
    @Test func noLongDashesInShippedTexts() throws {
        let roots = ["Zalizo", "WidgetExtension", "Packages/ZalizoCore/Sources"]
        let longDashes: Set<Character> = ["\u{2014}", "\u{2013}"]
        var offenders: [String] = []
        for root in roots {
            let enumerator = FileManager.default.enumerator(at: SeedFiles.url(root), includingPropertiesForKeys: nil)
            while let file = enumerator?.nextObject() as? URL {
                guard ["swift", "json", "xcstrings", "plist"].contains(file.pathExtension) else { continue }
                let text = try String(contentsOf: file, encoding: .utf8)
                if text.contains(where: { longDashes.contains($0) }) {
                    offenders.append(file.lastPathComponent)
                }
            }
        }
        #expect(offenders.isEmpty, "Long dashes in: \(offenders.joined(separator: ", "))")
    }
}
