import SwiftUI
import ZalizoCore

@MainActor
enum KnowledgeStore {
    private static var cached: [KnowledgeArticle]?

    static func articles(bundle: Bundle = .main) -> [KnowledgeArticle] {
        if let cached { return cached }
        let articles = bundle.url(forResource: "knowledge", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? KnowledgeFile.decode($0) }?.articles ?? []
        cached = articles
        return articles
    }
}

extension KnowledgeArticle.Category {
    var title: LocalizedStringResource {
        switch self {
        case .training: "Тренування"
        case .nutrition: "Харчування"
        case .recovery: "Відновлення"
        case .app: "Як користуватися додатком"
        }
    }

    var systemImage: String {
        switch self {
        case .training: "dumbbell"
        case .nutrition: "fork.knife"
        case .recovery: "bed.double"
        case .app: "chart.xyaxis.line"
        }
    }
}

/// Inline list of articles (used in Nutrition → Поради).
struct KnowledgeList: View {
    var category: KnowledgeArticle.Category?

    var body: some View {
        let articles = KnowledgeStore.articles().filter { category == nil || $0.category == category }
        VStack(spacing: Theme.Spacing.m) {
            ForEach(articles) { article in
                NavigationLink {
                    KnowledgeArticleView(article: article)
                } label: {
                    ArticleCard(article: article)
                }
                .buttonStyle(.plain)
            }
            DisclaimerBox()
        }
    }
}

/// Profile → База знань.
struct KnowledgeBaseView: View {
    var body: some View {
        let articles = KnowledgeStore.articles()
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(KnowledgeArticle.Category.allCases, id: \.self) { category in
                    let items = articles.filter { $0.category == category }
                    if !items.isEmpty {
                        CategoryHeader(category: category)
                        ForEach(items) { article in
                            NavigationLink {
                                KnowledgeArticleView(article: article)
                            } label: {
                                ArticleCard(article: article, showsIcon: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                DisclaimerBox()
                    .padding(.top, Theme.Spacing.s)
            }
            .padding(Theme.Spacing.l)
        }
        .zalScreen()
        .navigationTitle("База знань")
    }
}

struct KnowledgeArticleView: View {
    let article: KnowledgeArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack(spacing: Theme.Spacing.s) {
                        IconBadge(systemImage: article.category.systemImage, tint: Theme.Palette.accent, size: 30)
                        Text(article.category.title).eyebrow()
                    }
                    Text(article.title)
                        .font(.largeTitle.weight(.light))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(article.summary)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    ArticleParagraph(paragraph: paragraph)
                }
                DisclaimerBox()
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .zalScreen()
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Markdown with bold/italic; list markers become bullets.
    static func render(_ paragraph: String) -> AttributedString {
        let text = paragraph
            .components(separatedBy: "\n")
            .map { $0.hasPrefix("- ") ? "• \($0.dropFirst(2))" : $0 }
            .joined(separator: "\n")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Pieces

private struct ArticleCard: View {
    let article: KnowledgeArticle
    var showsIcon = true

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            if showsIcon {
                IconBadge(systemImage: article.category.systemImage, tint: Theme.Palette.accent)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct CategoryHeader: View {
    let category: KnowledgeArticle.Category

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            IconBadge(systemImage: category.systemImage, tint: Theme.Palette.accent, size: 30)
            Text(category.title).font(.title3.weight(.semibold))
        }
        .padding(.top, Theme.Spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Plain paragraphs read as body text; lists (bullets or numbers) become a glass "key notes" card.
private struct ArticleParagraph: View {
    let paragraph: String

    private enum Marker {
        case bullet
        case number(String)
        case plain
    }

    private struct Line: Identifiable {
        let id: Int
        let marker: Marker
        let text: String
    }

    private var lines: [Line] {
        paragraph.components(separatedBy: "\n").enumerated().map { index, raw -> Line in
            let (marker, text) = Self.split(raw)
            return Line(id: index, marker: marker, text: text)
        }
    }

    private var isList: Bool {
        lines.contains { line in
            if case .plain = line.marker { return false }
            return true
        }
    }

    var body: some View {
        if isList {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(lines) { line in
                    lineView(line)
                }
            }
            .cardStyle()
        } else {
            Text(KnowledgeArticleView.render(paragraph))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func lineView(_ line: Line) -> some View {
        switch line.marker {
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                GlowDot(size: 6)
                    .padding(.bottom, 3)
                textView(line.text)
            }
        case .number(let number):
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(number)
                    .font(.headline.weight(.light).monospacedDigit())
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(minWidth: 18, alignment: .leading)
                textView(line.text)
            }
        case .plain:
            textView(line.text)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func textView(_ text: String) -> some View {
        Text(KnowledgeArticleView.render(text))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "- text" → bullet, "2. text" → number, anything else stays plain.
    private static func split(_ line: String) -> (Marker, String) {
        if line.hasPrefix("- ") {
            return (.bullet, String(line.dropFirst(2)))
        }
        if let dot = line.firstIndex(of: "."), dot > line.startIndex,
           line[..<dot].allSatisfy(\.isNumber),
           line[line.index(after: dot)...].hasPrefix(" ") {
            let text = line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)
            return (.number(String(line[..<dot])), text)
        }
        return (.plain, line)
    }
}
