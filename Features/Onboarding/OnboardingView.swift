import ShahCore
import SwiftUI

/// Three pages: what Шаг does → Health access and privacy → daily goal.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var goalValue: Double = 5

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                WelcomePage().tag(0)
                HealthPage().tag(1)
                GoalPage(value: $goalValue, unit: model.unit).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: page)

            PageDots(count: 3, current: page)
                .padding(.vertical, 16)

            buttons
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
        }
        .background(Palette.background)
        .onAppear {
            goalValue = model.settings.goalValue(in: model.unit)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch page {
        case 0:
            Button { page = 1 } label: { Text("Далі").frame(maxWidth: .infinity) }
                .primaryActionStyle()
                .accessibilityIdentifier("onboarding.next")
        case 1:
            VStack(spacing: 4) {
                Button {
                    Task {
                        await model.requestAuthorization()
                        page = 2
                    }
                } label: {
                    Text("Дозволити доступ до Health").frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
                .accessibilityIdentifier("onboarding.allow")
                Button("Пізніше") { page = 2 }
                    .foregroundStyle(Palette.accentText)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("onboarding.later")
            }
        default:
            Button {
                let unit = model.unit
                model.updateSettings {
                    $0.setGoal(value: goalValue, in: unit)
                    $0.hasCompletedOnboarding = true
                }
                Task { await model.refresh() }
            } label: {
                Text("Почати").frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
            .accessibilityIdentifier("onboarding.start")
        }
    }
}

private struct WelcomePage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                TrailMark()
                    .frame(width: 180, height: 180)
                    .padding(.top, 60)
                Text("Шаг")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Text("Скільки ти пройшов сьогодні — за одну секунду.")
                    .font(.title3)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct HealthPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(LinearGradient(gradient: Palette.trail, startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: .rect(cornerRadius: 20, style: .continuous))
                    .padding(.top, 36)
                    .accessibilityHidden(true)
                Text("Дані з Apple Health")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Palette.textPrimary)
                Text("Шаг читає відстань і кроки, які iPhone та Apple Watch уже записують у Health.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                VStack(alignment: .leading, spacing: 18) {
                    Bullet(icon: "applewatch", title: "iPhone + Apple Watch",
                           text: "Без подвоєння: Health сам об'єднує записи з обох пристроїв.")
                    Bullet(icon: "icloud.slash", title: "Нічого не залишає телефон",
                           text: "Без серверів, акаунтів, аналітики й реклами.")
                    Bullet(icon: "checkmark.shield.fill", title: "Лише читання",
                           text: "Шаг нічого не записує в Health.")
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct Bullet: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .frame(width: 40, height: 40)
                .background(Palette.surface, in: .rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.textPrimary)
                Text(text).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GoalPage: View {
    @Binding var value: Double
    let unit: DistanceUnit

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 92
    private let presets: [Double] = [3, 5, 8, 10]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Твоя денна ціль")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, 44)
                Text("Кільце заповнюється до цієї відстані. Змінити можна будь-коли в налаштуваннях.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)

                HStack(spacing: 24) {
                    RoundButton(systemImage: "minus", label: "Зменшити ціль") { step(-1) }
                        .accessibilityIdentifier("goal.decrement")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Format.goalNumber(meters, unit))
                            .font(Typography.hero(numberSize))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: value))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(unit.shortLabel)
                            .font(.system(size: numberSize * 0.33, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .frame(minWidth: 140)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Денна ціль"))
                    .accessibilityValue(Text(Format.goal(meters, unit)))
                    .accessibilityAdjustableAction { direction in
                        step(direction == .increment ? 1 : -1)
                    }
                    .accessibilityIdentifier("goal.value")
                    RoundButton(systemImage: "plus", label: "Збільшити ціль") { step(1) }
                        .accessibilityIdentifier("goal.increment")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

                Text(Format.goalEstimate(meters))
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { preset in
                        let selected = abs(preset - value) < 0.01
                        Button {
                            withAnimation(.snappy) { value = preset }
                        } label: {
                            Text(Format.goal(unit.meters(fromValue: preset), unit))
                                .font(.callout.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .foregroundStyle(selected ? .white : Palette.textPrimary)
                                .background(selected ? Palette.accent : Palette.surface, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            }
            .padding(.horizontal, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sensoryFeedback(.selection, trigger: value)
    }

    private var meters: Double { unit.meters(fromValue: value) }

    private func step(_ direction: Double) {
        let next = value + direction * AppSettings.goalStep
        guard AppSettings.goalRange.contains(next) else { return }
        withAnimation(.snappy) { value = next }
    }
}

private struct RoundButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 56, height: 56)
                .background(Palette.surface, in: .circle)
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(Text(label))
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.accent : Palette.track)
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Крок \(current + 1) з \(count)"))
    }
}

#Preview("Онбординг") {
    PreviewHost(model: .preview(settings: AppSettings())) { OnboardingView() }
}

#Preview("Онбординг — темна") {
    PreviewHost(model: .preview(settings: AppSettings())) { OnboardingView() }
        .preferredColorScheme(.dark)
}

#Preview("Онбординг — великий шрифт") {
    PreviewHost(model: .preview(settings: AppSettings())) { OnboardingView() }
        .dynamicTypeSize(.accessibility2)
}
