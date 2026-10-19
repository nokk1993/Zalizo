import SwiftUI

/// A short burst of confetti each time `trigger` changes. Skipped with Reduce Motion.
struct ConfettiView: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    private static let duration: TimeInterval = 2.2
    private static let count = 70
    private static let colors: [Color] = [Palette.coral, Palette.amber, Color(hex: 0x3DD68C), Color(hex: 0x5AB2FF), Color(hex: 0xFF8AD8)]

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { context in
            Canvas { canvas, size in
                guard let start else { return }
                let t = context.date.timeIntervalSince(start)
                guard t >= 0, t < Self.duration else { return }
                for index in 0..<Self.count {
                    var rng = SplitMix64(seed: UInt64(index + 1) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(truncatingIfNeeded: trigger))
                    let angle = Double.random(in: (-0.95 * .pi)...(-0.05 * .pi), using: &rng)
                    let speed = Double.random(in: 260...560, using: &rng)
                    let spin = Double.random(in: -9...9, using: &rng)
                    let x = size.width / 2 + cos(angle) * speed * t
                    let y = size.height * 0.4 + sin(angle) * speed * t + 0.5 * 980 * t * t
                    var piece = canvas
                    piece.opacity = max(0, 1 - t / Self.duration)
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(spin * t))
                    let rect = index % 3 == 0 ? CGRect(x: -3, y: -3, width: 6, height: 6) : CGRect(x: -4, y: -7, width: 8, height: 14)
                    piece.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Self.colors[index % Self.colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            let started = Date.now
            start = started
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                if start == started { start = nil }
            }
        }
    }
}

/// Small deterministic generator so every burst looks the same for a trigger.
nonisolated struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
