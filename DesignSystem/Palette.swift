import SwiftUI

/// Brand colours. Shared by the app and the widgets, defined in code so the
/// widget extension needs no asset catalog.
///
/// Every semantic colour has light and dark values, plus a stronger variant
/// for Settings → Accessibility → Increase Contrast where the brand value is
/// below WCAG AA for text.
enum Palette {
    // Brand
    static let coral = Color(hex: 0xFF5A47)
    static let amber = Color(hex: 0xFFB547)
    static let ink = Color(hex: 0x1A1412)

    // Semantic
    static let accent = Color(light: 0xFF5A47, dark: 0xFF6B57, highContrastLight: 0xC9321F, highContrastDark: 0xFF8A78)
    /// Accent for small text (links, labels): AA on `background` and `surface`.
    static let accentText = Color(light: 0xC9321F, dark: 0xFF7A66)
    static let background = Color(light: 0xF7F4F2, dark: 0x000000)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1614)
    static let textPrimary = Color(light: 0x1A1412, dark: 0xF7F1EE)
    static let textSecondary = Color(light: 0x6E6560, dark: 0xA89F9A, highContrastLight: 0x4A423E, highContrastDark: 0xD0C8C3)
    static let track = Color(light: 0xEFE7E2, dark: 0x2A2421, highContrastLight: 0xD9CFC9, highContrastDark: 0x453B37)
    static let positive = Color(light: 0x1B7F4C, dark: 0x3DD68C)

    /// The trail from the app icon: amber start → coral end.
    static var trail: Gradient { Gradient(colors: [amber, coral]) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(light: UInt32, dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            let hex = switch (isDark, isHighContrast) {
            case (false, false): light
            case (true, false): dark
            case (false, true): highContrastLight ?? light
            case (true, true): highContrastDark ?? dark
            }
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
