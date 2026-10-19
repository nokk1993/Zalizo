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
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(article.title).font(.headline).foregroundStyle(.primary)
                        Text(article.summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
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
        List {
            ForEach(KnowledgeArticle.Category.allCases, id: \.self) { category in
                let items = articles.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { article in
                            NavigationLink {
                                KnowledgeArticleView(article: article)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(article.title)
                                    Text(article.summary).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Label { Text(category.title) } icon: { Image(systemName: category.systemImage) }
                    }
                }
            }
        }
        .navigationTitle("База знань")
    }
}

struct KnowledgeArticleView: View {
    let article: KnowledgeArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text(article.title).font(.title.bold())
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(Self.render(paragraph))
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclaimerBox()
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Markdown with bold/italic; list markers become bullets.
    static func render(_ paragraph: String) -> AttributedString {
        let text = paragraph
            .components(separatedBy: "\n")
            .map { $0.hasPrefix("- ") ? "• " + $0.dropFirst(2) : $0 }
            .joined(separator: "\n")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
