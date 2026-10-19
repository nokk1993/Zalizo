import SwiftData
import SwiftUI
import ZalizoCore

/// Profile → "Мої дані". Edits a draft; shows what changes in the plan before saving.
struct ProfileEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var original = ProfileSnapshot()
    @State private var draft = ProfileSnapshot()
    @State private var originalDumbbellStep = Defaults.dumbbellStepKg
    @State private var dumbbellStep = Defaults.dumbbellStepKg
    @State private var originalLifts: [KeyLift: LiftResult] = [:]
    @State private var lifts: [KeyLift: LiftResult] = [:]
    @State private var knowsLifts = false
    @State private var isLoaded = false
    @State private var review: ChangeReview?

    private var hasEdits: Bool {
        draft != original || dumbbellStep != originalDumbbellStep || effectiveLifts != originalLifts
    }

    private var effectiveLifts: [KeyLift: LiftResult] {
        knowsLifts ? lifts.filter { $0.value.isValid } : [:]
    }

    var body: some View {
        List {
            Section {
                link("Тіло", systemImage: "figure.stand", detail: "\(Int(draft.heightCm)) см · \(draft.weightKg.kgText) кг · \(draft.ageYears()) р.") {
                    BodySection(snapshot: $draft)
                }
                link("Досвід і ціль", systemImage: "target", detail: String(localized: draft.goal.title)) {
                    GoalSection(snapshot: $draft)
                }
                link("Розклад", systemImage: "calendar", detail: "\(draft.trainingDays.count) × тиждень · \(draft.sessionMinutes) хв") {
                    ScheduleSection(snapshot: $draft)
                }
                link("Активність", systemImage: "figure.walk", detail: String(localized: draft.activity.title)) {
                    ActivitySection(snapshot: $draft)
                }
            }
            .glassRows()
            Section {
                link("Обладнання", systemImage: "dumbbell", detail: "\(draft.equipment.subtracting([.bodyweight]).count) видів") {
                    EquipmentSection(snapshot: $draft, dumbbellStepKg: $dumbbellStep)
                }
                link("Обмеження", systemImage: "cross.case", detail: draft.limitations.isEmpty ? String(localized: "немає") : "\(draft.limitations.count)") {
                    LimitationsSection(snapshot: $draft)
                }
                link("Стартові ваги", systemImage: "list.number", detail: knowsLifts ? "\(effectiveLifts.count)" : String(localized: "калібрування")) {
                    LiftsSection(knowsLifts: $knowsLifts, lifts: $lifts)
                }
            }
            .glassRows()
            Section {
                link("Харчування", systemImage: "fork.knife", detail: "\(draft.mealsPerDay) прийоми") {
                    NutritionPreferencesSection(snapshot: $draft)
                }
                link("Цільова вага", systemImage: "flag.checkered", detail: draft.targetWeightKg.map { "\($0.kgText) кг" } ?? String(localized: "автоматично")) {
                    TargetWeightSection(snapshot: $draft)
                }
            }
            .glassRows()
        }
        .zalScreen()
        .navigationTitle("Мої дані")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Зберегти") { startSave() }
                    .bold()
                    .disabled(!hasEdits)
            }
        }
        .task { load() }
        .sheet(item: $review) { review in
            ChangeReviewSheet(review: review) {
                apply()
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func link<Content: View>(
        _ title: LocalizedStringResource, systemImage: String, detail: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        NavigationLink {
            ScrollView {
                content().padding(Theme.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .zalScreen()
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(systemImage: systemImage, tint: Theme.Palette.accent, size: 34)
                Text(title)
                Spacer(minLength: Theme.Spacing.s)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        original = ProfileStore.snapshot(in: context)
        draft = original
        originalDumbbellStep = ProfileStore.settings(in: context)?.dumbbellStepKg ?? Defaults.dumbbellStepKg
        dumbbellStep = originalDumbbellStep
        originalLifts = ProfileStore.baselines(in: context)
        lifts = originalLifts
        knowsLifts = !originalLifts.isEmpty
    }

    private func startSave() {
        let old = PlanCalculator.summary(for: original)
        let new = PlanCalculator.summary(for: draft)
        let changes = PlanCalculator.changes(from: old, to: new)
        if changes.isEmpty {
            apply()
        } else {
            review = ChangeReview(old: old, new: new, changes: changes)
        }
    }

    private func apply() {
        guard let profile = ProfileStore.profile(in: context) else { return }
        ProfileStore.apply(draft, to: profile, context: context)
        ProfileStore.settings(in: context)?.dumbbellStepKg = dumbbellStep
        ProfileStore.saveBaselines(effectiveLifts, context: context)
        try? context.save()
        Haptics.selection()
        dismiss()
    }
}

struct ChangeReview: Identifiable {
    let id = UUID()
    let old: PlanSummary
    let new: PlanSummary
    let changes: [PlanChange]
}

/// "Що зміниться" - confirmation before recalculating norms and forecast.
private struct ChangeReviewSheet: View {
    let review: ChangeReview
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(review.changes, id: \.field) { change in
                        LabeledContent {
                            Text(valueText(change))
                                .monospacedDigit()
                                .foregroundStyle(Theme.Palette.accent)
                        } label: {
                            Text(change.field.title)
                        }
                    }
                } footer: {
                    Text("Робочі ваги в програмі підлаштуються на наступному тренуванні.")
                }
                .glassRows()
            }
            .zalScreen()
            .navigationTitle("Що зміниться")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Застосувати") {
                        dismiss()
                        onConfirm()
                    }
                    .bold()
                }
            }
        }
    }

    private func valueText(_ change: PlanChange) -> String {
        if change.field == .program {
            return "\(String(localized: ProgramTitles.title(slug: review.old.recommendedProgramSlug))) → \(String(localized: ProgramTitles.title(slug: review.new.recommendedProgramSlug)))"
        }
        let unit = String(localized: change.field.unit)
        let old = change.old.map(\.preciseText) ?? "-"
        let new = change.new.map(\.preciseText) ?? "-"
        return "\(old) → \(new) \(unit)"
    }
}
