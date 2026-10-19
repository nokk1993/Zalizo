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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    if let snapshot {
                        ProfileHeader(snapshot: snapshot, summary: PlanCalculator.summary(for: snapshot))
                    }

                    dataGroup
                    progressGroup
                    appGroup
                    restartBlock
                    DisclaimerBox()
                }
                .buttonStyle(.plain)
                .padding(Theme.Spacing.l)
            }
            .zalScreen()
            .navigationTitle("Профіль")
            .confirmationDialog("Пройти анкету заново?", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("Пройти заново") { restartOnboarding() }
                Button("Скасувати", role: .cancel) {}
            }
        }
    }

    private var dataGroup: some View {
        LinkGroup(title: "Мої дані") {
            NavigationLink {
                ProfileEditView()
            } label: {
                ProfileRow(title: "Змінити мої дані", systemImage: "person.text.rectangle")
            }
            RowDivider()
            NavigationLink {
                PlanDetailsView()
            } label: {
                ProfileRow(title: "Норми і прогноз", systemImage: "chart.bar.doc.horizontal")
            }
        }
    }

    private var progressGroup: some View {
        LinkGroup(title: "Прогрес і знання") {
            NavigationLink {
                GoalsView()
            } label: {
                ProfileRow(title: "Цілі і досягнення", systemImage: "flag.checkered")
            }
            RowDivider()
            NavigationLink {
                KnowledgeBaseView()
            } label: {
                ProfileRow(title: "База знань", systemImage: "book")
            }
        }
    }

    private var appGroup: some View {
        LinkGroup(title: "Дані і додаток") {
            NavigationLink {
                BackupView()
            } label: {
                ProfileRow(title: "Резервна копія", systemImage: "externaldrive.badge.icloud")
            }
            RowDivider()
            NavigationLink {
                SettingsView()
            } label: {
                ProfileRow(title: "Налаштування", systemImage: "gearshape")
            }
        }
    }

    private var restartBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            LinkGroup {
                Button {
                    confirmRestart = true
                } label: {
                    ProfileRow(title: "Пройти анкету заново", systemImage: "arrow.counterclockwise", tint: Theme.Palette.accent, showsChevron: false)
                }
            }
            Text("Поточні відповіді будуть підставлені, історія тренувань і ваги не зміниться.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.s)
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
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.l) {
                Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color.white)
                    .frame(width: 68, height: 68)
                    .glassEffect(.regular, in: Circle())
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: snapshot.goal.systemImage)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.Palette.onAccent)
                            .frame(width: 24, height: 24)
                            .background(Theme.Palette.accent, in: Circle())
                            .shadow(color: Theme.Palette.accent.opacity(0.6), radius: 6)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ціль").eyebrow()
                    Text(snapshot.goal.title).font(.title2.weight(.semibold))
                    Text("\(snapshot.weightKg.kgText) кг → \(summary.targetWeightKg.kgText) кг")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
            .accessibilityElement(children: .combine)

            HStack(spacing: Theme.Spacing.s) {
                StatTile(title: "Норма", value: summary.targets.restDay.kcal.groupedText, unit: "ккал", systemImage: "flame.fill")
                StatTile(title: "Білок", value: "\(summary.targets.restDay.proteinG)", unit: "г", systemImage: "bolt.fill", tint: Theme.Palette.protein)
            }
        }
    }
}

/// Titled glass group of rows.
private struct LinkGroup<Content: View>: View {
    var title: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title {
                Text(title)
                    .eyebrow()
                    .padding(.horizontal, Theme.Spacing.s)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                content
            }
            .background { GlassSurface() }
        }
    }
}

private struct ProfileRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    var tint: Color = .primary
    var showsChevron = true

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconBadge(systemImage: systemImage, tint: tint)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.primary)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .frame(minHeight: Theme.largeTapTarget)
        .contentShape(.rect)
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 70)
            .accessibilityHidden(true)
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
        .zalScreen()
        .navigationTitle("Норми і прогноз")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .previewData()
}
