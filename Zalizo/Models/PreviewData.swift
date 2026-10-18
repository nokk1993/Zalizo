import Foundation
import SwiftData
import SwiftUI

extension View {
    /// In-memory container with fictional demo data for SwiftUI previews. Not a real person.
    func previewData() -> some View {
        modelContainer(for: SchemaV1.models, inMemory: true) { result in
            guard case .success(let container) = result else { return }
            Task { @MainActor in PreviewData.populate(container.mainContext) }
        }
    }
}

@MainActor
enum PreviewData {
    static func populate(_ context: ModelContext) {
        let profile = UserProfile()
        profile.onboardingCompleted = true
        profile.heightCm = 180
        context.insert(profile)
        context.insert(AppSettings())
        let calendar = Calendar.current
        for dayOffset in 0..<21 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) {
                context.insert(BodyWeightEntry(date: date, weightKg: 70 + Double(21 - dayOffset) * 0.04))
            }
        }
        try? context.save()
    }
}
