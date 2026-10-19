import SwiftUI
import UIKit

/// Design tokens of «Зал»: dark navy canvas, frosted glass surfaces, lime glow accent,
/// light typography with bold accent words. The app is dark-only by design.
enum Theme {
    enum Palette {
        /// Lime glow: primary actions, rings, selection. Text on it uses `onAccent`.
        static let accent = Color(red: 0.80, green: 0.98, blue: 0.24)
        /// Olive shade for the glowing blob inside lime cards.
        static let accentDeep = Color(red: 0.33, green: 0.50, blue: 0.05)
        static let onAccent = Color(red: 0.04, green: 0.06, blue: 0.02)
        /// Cool rim light: secondary data, links to details.
        static let blue = Color(red: 0.36, green: 0.55, blue: 1.0)
        /// Tint of monochrome exercise photos.
        static let ice = Color(red: 0.68, green: 0.76, blue: 0.90)

        static let canvasTop = Color(red: 0.08, green: 0.11, blue: 0.18)
        static let canvasBottom = Color(red: 0.012, green: 0.016, blue: 0.027)
        /// Translucent fill of Form/List rows and flat controls.
        static let row = Color.white.opacity(0.07)
        static let stroke = Color.white.opacity(0.12)
        static let textSecondary = Color.white.opacity(0.62)
        static let textTertiary = Color.white.opacity(0.38)

        static let protein = Color("Protein")
        static let fat = Color("Fat")
        static let carbs = Color("Carbs")
        static let water = Color("Water")
        static let success = accent
        static let warning = Color(red: 1.0, green: 0.72, blue: 0.32)
        static let danger = Color(red: 1.0, green: 0.42, blue: 0.40)
        static let warmup = Color.white.opacity(0.45)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 26
        static let hero: CGFloat = 32
        static let control: CGFloat = 16
    }

    /// Minimum touch target in workout mode (sweaty fingers).
    static let largeTapTarget: CGFloat = 56

    /// Large navigation titles in the light weight of the visual style.
    @MainActor static func configureAppearance() {
        let base = UIFont.systemFont(ofSize: 34, weight: .light)
        let large = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: base)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: large]
    }
}

extension View {
    /// Standard frosted glass card.
    func cardStyle(inset: CGFloat = Theme.Spacing.l, tint: Color? = nil) -> some View {
        padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { GlassSurface(tint: tint) }
    }

    /// Glowing lime card for the single most important thing on a screen.
    func highlightCardStyle(inset: CGFloat = Theme.Spacing.xl) -> some View {
        padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Theme.Palette.onAccent)
            .environment(\.colorScheme, .light)
            .background { HighlightSurface() }
    }

    /// White card with dark text (summary dashboards).
    func lightCardStyle(inset: CGFloat = Theme.Spacing.xl) -> some View {
        padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.black)
            .environment(\.colorScheme, .light)
            .background { LightSurface() }
    }

    /// Dark canvas behind a screen (ScrollView, Form or List).
    func zalScreen() -> some View {
        scrollContentBackground(.hidden)
            .background { ZalBackground() }
    }

    /// Translucent rows on the dark canvas. Apply to each `Section` of a Form/List.
    func glassRows() -> some View {
        listRowBackground(Theme.Palette.row)
    }

    /// Small uppercase caption above a title ("ПОНЕДІЛОК, 19 ЖОВТНЯ").
    func eyebrow() -> some View {
        font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }

    /// The app look: dark scheme and lime tint.
    func themed() -> some View {
        preferredColorScheme(.dark)
            .tint(Theme.Palette.accent)
    }
}

// MARK: - Surfaces

/// Navy-to-black gradient with a cool rim light and a faint lime glow.
struct ZalBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.Palette.canvasTop, Theme.Palette.canvasBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Theme.Palette.blue.opacity(0.28), .clear],
                center: UnitPoint(x: 0.95, y: 0), startRadius: 10, endRadius: 420
            )
            RadialGradient(
                colors: [Theme.Palette.accent.opacity(0.08), .clear],
                center: UnitPoint(x: 0, y: 0.9), startRadius: 10, endRadius: 380
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Frosted glass: material blur, soft white sheen and a light edge.
struct GlassSurface: View {
    var cornerRadius: CGFloat = Theme.Radius.card
    var tint: Color?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let sheen = tint ?? .white
        shape.fill(.ultraThinMaterial)
            .overlay {
                shape.fill(LinearGradient(
                    colors: [sheen.opacity(tint == nil ? 0.09 : 0.18), sheen.opacity(0.02)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), lineWidth: 1)
            }
    }
}

/// Lime card with an olive blob and a highlight, glowing onto the canvas.
struct HighlightSurface: View {
    var cornerRadius: CGFloat = Theme.Radius.hero

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape.fill(Theme.Palette.accent)
            .overlay {
                shape.fill(RadialGradient(
                    colors: [Theme.Palette.accentDeep.opacity(0.85), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 320
                ))
            }
            .overlay {
                shape.fill(RadialGradient(
                    colors: [Color.white.opacity(0.5), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 220
                ))
            }
            .shadow(color: Theme.Palette.accent.opacity(0.28), radius: 28, y: 12)
    }
}

/// Bright card on the dark canvas.
struct LightSurface: View {
    var cornerRadius: CGFloat = Theme.Radius.hero

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(white: 0.96))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
    }
}

// MARK: - Buttons

/// Lime capsule with dark text: the main action of a screen.
struct ZalPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.Palette.onAccent)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .frame(minHeight: 50)
            .background { Capsule().fill(Theme.Palette.accent) }
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1) }
            .shadow(color: Theme.Palette.accent.opacity(isEnabled ? 0.4 : 0), radius: 16, y: 6)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Near-black capsule with lime text, for actions placed on lime cards.
struct ZalDarkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.Palette.accent)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .frame(minHeight: 50)
            .background { Capsule().fill(Theme.Palette.onAccent) }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == ZalPrimaryButtonStyle {
    static var zalPrimary: ZalPrimaryButtonStyle { ZalPrimaryButtonStyle() }
}

extension ButtonStyle where Self == ZalDarkButtonStyle {
    static var zalDark: ZalDarkButtonStyle { ZalDarkButtonStyle() }
}
