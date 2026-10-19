import ActivityKit
import SwiftUI
import WidgetKit
import ZalizoCore

@main
struct ZalizoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

/// Lock screen + Dynamic Island: rest countdown and the next set.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LockScreenView(state: context.state, title: context.attributes.workoutTitle)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("\(context.state.setsDone)/\(context.state.setsTotal)")
                    } icon: {
                        Image(systemName: "dumbbell.fill")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(end: context.state.restEnd)
                        .font(.title3.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName).font(.headline).lineLimit(1)
                        Text(context.state.nextSet).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundStyle(.orange)
            } compactTrailing: {
                RestCountdown(end: context.state.restEnd)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: context.state.restEnd == nil ? "dumbbell.fill" : "timer")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: RestActivityAttributes.ContentState
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(state.exerciseName).font(.headline).lineLimit(1)
                Text("Далі: \(state.nextSet)").font(.subheadline)
                Text("Підходів: \(state.setsDone)/\(state.setsTotal)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                if state.restEnd != nil {
                    Text("Відпочинок").font(.caption).foregroundStyle(.secondary)
                }
                RestCountdown(end: state.restEnd)
                    .font(.largeTitle.monospacedDigit().bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }
}

/// Counts down without app updates (the system renders the timer).
private struct RestCountdown: View {
    let end: Date?

    var body: some View {
        if let end, end > .now {
            Text(timerInterval: Date.now...end, countsDown: true)
                .multilineTextAlignment(.trailing)
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
        }
    }
}
