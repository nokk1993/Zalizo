import SwiftData
import SwiftUI
import ZalizoCore

/// Design tokens. Colors come from the asset catalog (light + dark variants).
enum Theme {
    enum Palette {
        static let accent = Color.accentColor
        static let protein = Color("Protein")
        static let fat = Color("Fat")
        static let carbs = Color("Carbs")
        static let water = Color("Water")
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let warmup = Color.secondary
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 20
        static let control: CGFloat = 14
    }

    /// Minimum touch target in workout mode (sweaty fingers).
    static let largeTapTarget: CGFloat = 56
}

extension View {
    /// Standard content card used across screens.
    func cardStyle() -> some View {
        padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
    }

    /// Applies the user's theme preference from settings.
    func themed() -> some View {
        modifier(ThemeModifier())
    }
}

private struct ThemeModifier: ViewModifier {
    @Query private var settings: [AppSettings]

    func body(content: Content) -> some View {
        content.preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch settings.first?.theme ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
