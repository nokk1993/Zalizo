import SwiftUI

/// The goal ring: the icon's amber → coral trail with a white "you are here" knob.
///
/// Fills from 0 on appear and animates between values; with Reduce Motion it
/// jumps straight to the value. Progress above 1 shows a full ring.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 28
    var showsKnob = true
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        let target = clamped(progress)
        let value = animated && !reduceMotion ? shown : target
        let inset = lineWidth / 2
        ZStack {
            Circle()
                .inset(by: inset)
                .stroke(Palette.track, lineWidth: lineWidth)
            if value > 0 {
                // Round caps are drawn as separate dots so the start keeps the
                // gradient's first colour instead of wrapping to its last.
                RingDot(progress: 0, radius: inset, inset: inset)
                    .fill(Palette.amber)
                RingArc(progress: value, inset: inset)
                    .stroke(
                        AngularGradient(gradient: Palette.trail, center: .center,
                                        startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * max(target, 0.01))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                RingDot(progress: value, radius: inset, inset: inset)
                    .fill(Palette.coral)
                if showsKnob {
                    RingDot(progress: value, radius: lineWidth * 0.28, inset: inset)
                        .fill(.white)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard animated, !reduceMotion else { return }
            withAnimation(.spring(duration: 1.1, bounce: 0.15).delay(0.1)) { shown = target }
        }
        .onChange(of: target) { _, newValue in
            withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.1)) { shown = newValue }
        }
        .accessibilityHidden(true)
    }

    private func clamped(_ p: Double) -> Double {
        p.isFinite ? min(max(p, 0), 1) : 0
    }
}

/// Clockwise arc from 12 o'clock covering `progress` of the circle.
nonisolated struct RingArc: Shape {
    var progress: Double
    var inset: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2 - inset
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
                    startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
        return path
    }
}

/// A dot sitting on the ring at `progress`.
nonisolated struct RingDot: Shape {
    var progress: Double
    var radius: CGFloat
    var inset: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let ringRadius = min(rect.width, rect.height) / 2 - inset
        let angle = (-90 + 360 * progress) * .pi / 180
        let center = CGPoint(x: rect.midX + ringRadius * cos(angle), y: rect.midY + ringRadius * sin(angle))
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

#Preview("Кільця") {
    HStack(spacing: 20) {
        ProgressRing(progress: 0.0, lineWidth: 14)
        ProgressRing(progress: 0.31, lineWidth: 14)
        ProgressRing(progress: 0.74, lineWidth: 14)
        ProgressRing(progress: 1.24, lineWidth: 14)
    }
    .padding()
    .background(Palette.background)
}
