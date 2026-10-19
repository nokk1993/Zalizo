import SwiftUI

/// The app icon's trajectory as a vector, for onboarding and empty states.
/// Draws itself on appear unless Reduce Motion is on.
struct TrailMark: View {
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 1024
            let progress = animated && !reduceMotion ? drawn : 1
            ZStack {
                TrailPath()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(gradient: Palette.trail, startPoint: .bottomLeading, endPoint: .topTrailing),
                        style: StrokeStyle(lineWidth: 96 * scale, lineCap: .round)
                    )
                Circle()
                    .strokeBorder(Palette.amber, lineWidth: 24 * scale)
                    .background(Circle().fill(Palette.background))
                    .frame(width: 92 * scale, height: 92 * scale)
                    .position(x: 262 * scale, y: 786 * scale)
                Circle()
                    .fill(Palette.textPrimary)
                    .frame(width: 172 * scale, height: 172 * scale)
                    .position(x: 762 * scale, y: 262 * scale)
                    .scaleEffect(progress >= 1 ? 1 : 0.01, anchor: .center)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard animated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1)) { drawn = 1 }
        }
        .accessibilityHidden(true)
    }
}

/// Same curve as Brand/Icon/shah-icon.svg, in a 1024 × 1024 box.
nonisolated struct TrailPath: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 1024
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(262, 786))
        path.addCurve(to: p(512, 500), control1: p(262, 560), control2: p(470, 640))
        path.addCurve(to: p(762, 262), control1: p(554, 360), control2: p(650, 300))
        return path
    }
}

#Preview {
    TrailMark()
        .frame(width: 200)
        .padding()
        .background(Palette.background)
}
