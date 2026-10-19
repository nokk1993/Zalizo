import SwiftData
import SwiftUI

/// Shows the questionnaire until it is completed, then the main tabs.
struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first, !profile.onboardingCompleted {
            OnboardingContainer(profile: profile)
                .transition(.opacity)
        } else {
            RootTabView()
                .transition(.opacity)
        }
    }
}
