import SwiftData
import SwiftUI
import ZalizoCore

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(ProfileView.latestWeightDescriptor) private var latestWeights: [BodyWeightEntry]
    @State private var confirmRestart = false

    nonisolated static var latestWeightDescriptor: FetchDescriptor<BodyWeightEntry> {
        var descriptor = FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    private var snapshot: ProfileSnapshot? {
        profiles.first.map { ProfileStore.snapshot(of: $0, currentWeightKg: latestWeights.first?.weightKg) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let snapshot {
                    Section {
                        ProfileHeader(snapshot: snapshot, summary: PlanCalculator.summary(for: snapshot))
                    }
                }

                Section("Мої дані") {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        Label("Змінити мої дані", systemImage: "person.text.rectangle")
                    }
                    NavigationLink {
                        PlanDetailsView()
                    } label: {
                        Label("Норми і прогноз", systemImage: "chart.bar.doc.horizontal")
                    }
                }

                Section {
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label("Цілі і досягнення", systemImage: "flag.checkered")
                    }
                    NavigationLink {
                        KnowledgeBaseView()
                    } label: {
                        Label("База знань", systemImage: "book")
                    }
                }

                Section {
                    NavigationLink {
                        BackupView()
                    } label: {
                        Label("Резервна копія", systemImage: "externaldrive.badge.icloud")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Налаштування", systemImage: "gearshape")
                    }
                }

                Section {
                    Button {
                        confirmRestart = true
                    } label: {
                        Label("Пройти анкету заново", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Поточні відповіді будуть підставлені, історія тренувань і ваги не зміниться.")
                }

                Section {
                    DisclaimerBox()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Профіль")
            .confirmationDialog("Пройти анкету заново?", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("Пройти заново") { restartOnboarding() }
                Button("Скасувати", role: .cancel) {}
            }
        }
    }

    private func restartOnboarding() {
        guard let profile = profiles.first else { return }
        profile.onboardingStep = 0
        profile.onboardingCompleted = false
        try? context.save()
    }
}

private struct ProfileHeader: View {
    let snapshot: ProfileSnapshot
    let summary: PlanSummary

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            Image(systemName: snapshot.goal.systemImage)
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.goal.title).font(.headline)
                Text("\(snapshot.weightKg.kgText) кг → \(summary.targetWeightKg.kgText) кг")
                    .foregroundStyle(.secondary)
                Text("\(summary.targets.restDay.kcal.groupedText) ккал · Б \(summary.targets.restDay.proteinG) г")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Profile → "Норми і прогноз".
struct PlanDetailsView: View {
    @Query private var profiles: [UserProfile]
    @Query(ProfileView.latestWeightDescriptor) private var latestWeights: [BodyWeightEntry]

    var body: some View {
        ScrollView {
            if let profile = profiles.first {
                let snapshot = ProfileStore.snapshot(of: profile, currentWeightKg: latestWeights.first?.weightKg)
                PlanSummaryCard(summary: PlanCalculator.summary(for: snapshot), snapshot: snapshot)
                    .padding(Theme.Spacing.l)
            }
        }
        .navigationTitle("Норми і прогноз")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .previewData()
}
