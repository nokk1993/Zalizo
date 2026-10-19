import ShahCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let unit = model.unit
        NavigationStack {
            Form {
                Section {
                    Stepper(value: goalBinding(unit), in: AppSettings.goalRange, step: AppSettings.goalStep) {
                        LabeledContent("Денна ціль") {
                            Text(Format.goal(model.settings.goalMeters, unit))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textPrimary)
                                .fontWeight(.semibold)
                        }
                    }
                    .accessibilityIdentifier("settings.goal")
                } header: {
                    Text("Ціль")
                } footer: {
                    Text("Крок зміни — \(Format.goal(unit.meters(fromValue: AppSettings.goalStep), unit)). Ціль використовується для кільця, серій і віджетів.")
                }

                Section("Вигляд") {
                    Picker("Одиниці", selection: unitBinding) {
                        Text("км").tag(DistanceUnit.kilometers)
                        Text("милі").tag(DistanceUnit.miles)
                    }
                    .accessibilityIdentifier("settings.units")
                    Picker("Тема", selection: themeBinding) {
                        Text("Авто").tag(AppTheme.system)
                        Text("Світла").tag(AppTheme.light)
                        Text("Темна").tag(AppTheme.dark)
                    }
                    .accessibilityIdentifier("settings.theme")
                }

                Section {
                    NavigationLink {
                        HealthAccessView()
                    } label: {
                        Label("Доступ до Health", systemImage: "heart.text.square")
                    }
                } header: {
                    Text("Дані")
                } footer: {
                    Text("Шаг лише читає дані з Apple Health на цьому iPhone. Нічого не відправляється в інтернет.")
                }

                Section("Про застосунок") {
                    LabeledContent("Версія", value: Self.version)
                        .accessibilityIdentifier("settings.version")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Налаштування")
        }
    }

    private func goalBinding(_ unit: DistanceUnit) -> Binding<Double> {
        Binding(
            get: { model.settings.goalValue(in: unit) },
            set: { value in model.updateSettings { $0.setGoal(value: value, in: unit) } }
        )
    }

    private var unitBinding: Binding<DistanceUnit> {
        Binding(
            get: { model.unit },
            set: { unit in model.updateSettings { $0.unitOverride = unit } }
        )
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { model.settings.theme },
            set: { theme in model.updateSettings { $0.theme = theme } }
        )
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Where to check read access. HealthKit never reports a denial to the app.
struct HealthAccessView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                Text("Шаг читає лише «Відстань ходьби та бігу» і «Кроки». Якщо число не збігається з Apple Health або дорівнює нулю, перевір доступ:")
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Параметри → Здоров'я → Доступ до даних і пристрої → Шаг")
                    Text("2. Увімкни «Відстань ходьби та бігу» і «Кроки».")
                    Text("3. Повернись у Шаг і потягни екран вниз, щоб оновити.")
                }
                .font(.callout)
            }
            Section {
                Button("Запитати доступ ще раз") {
                    Task { await model.requestAuthorization() }
                }
                Button("Відкрити «Здоров'я»") {
                    if let url = URL(string: "x-apple-health://") { openURL(url) }
                }
            } footer: {
                Text("iOS показує запит доступу лише один раз. Якщо ти вже відповів, змінити вибір можна тільки в Параметрах.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Доступ до Health")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Налаштування") {
    PreviewHost { SettingsView() }
}

#Preview("Налаштування — темна") {
    PreviewHost { SettingsView() }
        .preferredColorScheme(.dark)
}

#Preview("Налаштування — великий шрифт") {
    PreviewHost { SettingsView() }
        .dynamicTypeSize(.accessibility2)
}
