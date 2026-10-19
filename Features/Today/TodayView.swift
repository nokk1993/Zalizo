import ShahCore
import SwiftUI

/// Phase 2 placeholder; replaced by the designed screen in phase 3.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 76

    var body: some View {
        let summary = model.summary
        VStack(spacing: 12) {
            Text("Сьогодні")
                .font(.largeTitle.bold())
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(DistanceFormat.number(meters: summary.meters, unit: model.unit))
                    .font(Typography.hero(heroSize))
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("today.distance")
                Text(model.unit.shortLabel)
                    .font(Typography.heroUnit)
                    .foregroundStyle(Palette.textSecondary)
            }
            Text("\(DistanceFormat.steps(summary.steps)) кроків")
                .font(Typography.pill)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .animation(.default, value: summary.meters)
    }
}

#Preview {
    let model = AppModel.preview()
    TodayView()
        .environment(model)
        .task { await model.refresh() }
}
