import Combine
import SwiftUI
import UIKit

extension View {
    /// Calls `action` at midnight, after a manual clock change and after a
    /// time-zone change (travel), so "today" never shows yesterday's number.
    func onSystemClockChange(_ action: @escaping () -> Void) -> some View {
        let center = NotificationCenter.default
        let events = Publishers.MergeMany(
            center.publisher(for: .NSCalendarDayChanged),
            center.publisher(for: UIApplication.significantTimeChangeNotification),
            center.publisher(for: .NSSystemTimeZoneDidChange)
        )
        .receive(on: RunLoop.main)
        return onReceive(events) { _ in action() }
    }
}
