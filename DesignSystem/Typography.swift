import ShahCore
import SwiftUI

/// SF Pro Rounded for numbers, system text styles for everything else.
enum Typography {
    /// The hero number. Pass a size from `@ScaledMetric` so it follows Dynamic Type.
    static func hero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static let heroUnit = Font.system(.title2, design: .rounded, weight: .semibold)
    static let cardValue = Font.system(.title2, design: .rounded, weight: .bold)
    static let cardLabel = Font.footnote.weight(.semibold)
    static let pill = Font.callout.weight(.semibold)
}

extension DistanceUnit {
    /// Short label shown next to numbers: «км» / «km», «милі» / «mi».
    var shortLabel: LocalizedStringResource {
        switch self {
        case .kilometers: "км"
        case .miles: "милі"
        }
    }
}
