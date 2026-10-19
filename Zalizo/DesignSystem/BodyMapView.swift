import SwiftUI
import ZalizoCore

/// Simplified front/back body diagram on the dark canvas. Each muscle group has an intensity 0…1.
/// Exercise map (`init(primary:secondary:)`): primary = 1 in `tint` with a glow, secondary = 0.5 in blue.
/// Heat map (`init(intensities:)`, e.g. weekly sets / 20): ice-blue (low) → lime (good) → warning (above 1).
struct BodyMapView: View {
    let intensities: [MuscleGroup: Double]
    var tint: Color = Theme.Palette.accent
    var isExerciseMap = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            figure(side: .front, title: "Спереду")
            figure(side: .back, title: "Ззаду")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private func figure(side: BodySide, title: LocalizedStringResource) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Canvas { context, size in
                let scale = min(size.width / BodyShapes.width, size.height / BodyShapes.height)
                let offsetX = (size.width - BodyShapes.width * scale) / 2
                context.translateBy(x: offsetX, y: 0)
                context.scaleBy(x: scale, y: scale)
                let base = Color.white.opacity(0.08)
                let outline = Color.white.opacity(0.2)
                for part in BodyShapes.neutral(side) {
                    context.fill(part, with: .color(base))
                    context.stroke(part, with: .color(outline), lineWidth: 0.6)
                }
                for region in BodyShapes.regions(side) {
                    let value = intensities[region.muscle] ?? 0
                    if let color = fill(for: value) {
                        var glow = context
                        glow.addFilter(.shadow(color: color.opacity(0.7), radius: 3))
                        glow.fill(region.path, with: .color(color))
                    } else {
                        context.fill(region.path, with: .color(base))
                    }
                    context.stroke(region.path, with: .color(outline), lineWidth: 0.6)
                }
            }
            .aspectRatio(BodyShapes.width / BodyShapes.height, contentMode: .fit)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// nil = muscle not involved (drawn as the neutral silhouette).
    private func fill(for value: Double) -> Color? {
        guard value > 0 else { return nil }
        if isExerciseMap {
            return value >= 1 ? tint : Theme.Palette.blue.opacity(0.85)
        }
        if value > 1 { return Theme.Palette.warning }
        if value < 0.5 { return Theme.Palette.ice.opacity(0.3 + value) }
        return tint.opacity(0.55 + 0.9 * (value - 0.5))
    }

    private var accessibilitySummary: String {
        let active = intensities.filter { $0.value > 0 }.sorted { $0.value > $1.value }
        guard !active.isEmpty else { return String(localized: "Схема м'язів") }
        let names = active.map { String(localized: $0.key.title) }.joined(separator: ", ")
        return String(localized: "Задіяні м'язи: \(names)")
    }
}

enum BodySide {
    case front, back
}

/// Hand-drawn vector contours in a 100 × 220 coordinate space.
enum BodyShapes {
    static let width: CGFloat = 100
    static let height: CGFloat = 220

    struct Region {
        let muscle: MuscleGroup
        let path: Path
    }

    private static func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h))
    }

    private static func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    /// Mirrors a left-side shape to the right side of the body.
    private static func pair(_ path: Path) -> Path {
        var combined = path
        combined.addPath(path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)))
        return combined
    }

    /// Head, neck, hands, pelvis, feet - never highlighted.
    static func neutral(_ side: BodySide) -> [Path] {
        var parts = [
            ellipse(39, 2, 22, 25),                 // head
            rounded(44, 25, 12, 9, 3),              // neck
            pair(ellipse(8, 99, 10, 12)),           // hands
            rounded(31, 95, 38, 16, 6),             // pelvis
            pair(rounded(32, 204, 14, 10, 4))       // feet
        ]
        if side == .front {
            parts.append(pair(rounded(33, 158, 12, 46, 6))) // shins
        }
        return parts
    }

    static func regions(_ side: BodySide) -> [Region] {
        switch side {
        case .front:
            [
                Region(muscle: .traps, path: pair(rounded(36, 31, 10, 6, 3))),
                Region(muscle: .shoulders, path: pair(ellipse(17, 34, 15, 18))),
                Region(muscle: .chest, path: pair(rounded(31, 37, 18, 20, 7))),
                Region(muscle: .abs, path: rounded(38, 58, 24, 38, 7)),
                Region(muscle: .biceps, path: pair(rounded(15, 51, 11, 25, 5.5))),
                Region(muscle: .forearms, path: pair(rounded(11, 75, 10, 25, 5))),
                Region(muscle: .quads, path: pair(rounded(31, 108, 18, 48, 9)))
            ]
        case .back:
            [
                Region(muscle: .traps, path: diamond()),
                Region(muscle: .shoulders, path: pair(ellipse(17, 34, 15, 18))),
                Region(muscle: .back, path: pair(rounded(31, 47, 18, 44, 8))),
                Region(muscle: .triceps, path: pair(rounded(15, 51, 11, 25, 5.5))),
                Region(muscle: .forearms, path: pair(rounded(11, 75, 10, 25, 5))),
                Region(muscle: .glutes, path: pair(ellipse(31, 94, 19, 20))),
                Region(muscle: .hamstrings, path: pair(rounded(31, 114, 18, 44, 9))),
                Region(muscle: .calves, path: pair(rounded(33, 160, 13, 42, 6.5)))
            ]
        }
    }

    private static func diamond() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 28))
        path.addLine(to: CGPoint(x: 68, y: 38))
        path.addLine(to: CGPoint(x: 50, y: 62))
        path.addLine(to: CGPoint(x: 32, y: 38))
        path.closeSubpath()
        return path
    }
}

extension BodyMapView {
    /// Primary muscles at full intensity, secondary at half.
    init(primary: [MuscleGroup], secondary: [MuscleGroup], tint: Color = Theme.Palette.accent) {
        var values: [MuscleGroup: Double] = [:]
        secondary.forEach { values[$0] = 0.5 }
        primary.forEach { values[$0] = 1 }
        self.init(intensities: values, tint: tint, isExerciseMap: true)
    }
}

#Preview {
    VStack(spacing: 24) {
        BodyMapView(primary: [.chest], secondary: [.triceps, .shoulders])
            .frame(height: 220)
        BodyMapView(intensities: [.chest: 0.3, .back: 0.8, .quads: 1.2, .biceps: 0.6])
            .frame(height: 220)
    }
    .padding()
    .zalScreen()
    .themed()
}
