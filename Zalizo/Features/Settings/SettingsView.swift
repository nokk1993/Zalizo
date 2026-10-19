import SwiftData
import SwiftUI
import ZalizoCore

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]

    var body: some View {
        if let settings = settingsRows.first {
            SettingsForm(settings: settings)
        } else {
            ProgressView()
        }
    }
}

private struct SettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var context
    @State private var confirmReset = false
    @State private var confirmResetFinal = false
    @State private var permissionDenied = false
    @AppStorage(LiveActivityService.enabledKey) private var liveActivity = true
    @State private var healthEnabled = HealthService.isEnabled
    @State private var healthMessage: String?

    private let allPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5]

    var body: some View {
        Form {
            Section {
                LabeledContent("Одиниці", value: String(localized: "кг, см, ккал"))
                Picker("Крок штанги", selection: $settings.barbellStepKg) {
                    Text("1 кг").tag(1.0)
                    Text("2,5 кг").tag(2.5)
                    Text("5 кг").tag(5.0)
                }
                Picker("Крок гантелей", selection: $settings.dumbbellStepKg) {
                    Text("1 кг").tag(1.0)
                    Text("2 кг").tag(2.0)
                    Text("2,5 кг").tag(2.5)
                }
                Picker("Крок тренажерів", selection: $settings.machineStepKg) {
                    Text("2,5 кг").tag(2.5)
                    Text("5 кг").tag(5.0)
                    Text("10 кг").tag(10.0)
                }
                Picker("Вага грифа", selection: $settings.barWeightKg) {
                    Text("10 кг").tag(10.0)
                    Text("15 кг").tag(15.0)
                    Text("20 кг").tag(20.0)
                }
            } header: {
                Text("Вага")
            }

            Section {
                ForEach(allPlates, id: \.self) { plate in
                    Toggle(isOn: plateBinding(plate)) {
                        Text("\(plate.preciseText) кг")
                    }
                }
            } header: {
                Text("Диски для калькулятора")
            } footer: {
                Text("Позначені диски є у твоєму залі (пара кожного).")
            }

            Section("Тренування") {
                Picker("Відпочинок за замовчуванням", selection: $settings.defaultRestSeconds) {
                    ForEach([60, 90, 120, 150, 180], id: \.self) { Text(RestFormat.text($0)).tag($0) }
                }
                Toggle("Таймер відпочинку автоматично", isOn: $settings.autoStartRestTimer)
                Toggle("Звук", isOn: $settings.soundEnabled)
                Toggle("Вібрація", isOn: $settings.hapticsEnabled)
                Toggle("«Як ти сьогодні?» перед тренуванням", isOn: $settings.useWellnessCheck)
                Toggle("Таймер на заблокованому екрані (Live Activity)", isOn: $liveActivity)
                Picker("Формула 1ПМ", selection: Binding(get: { settings.oneRMFormula }, set: { settings.oneRMFormula = $0 })) {
                    Text("Еплі").tag(OneRMFormula.epley)
                    Text("Бжицкі").tag(OneRMFormula.brzycki)
                }
            }

            Section {
                reminderToggle("Нагадування про тренування", isOn: $settings.trainingReminderEnabled)
                if settings.trainingReminderEnabled {
                    DatePicker("Час", selection: timeBinding($settings.trainingReminderMinutes), displayedComponents: .hourAndMinute)
                }
                reminderToggle("Зважування", isOn: $settings.weighInReminderEnabled)
                if settings.weighInReminderEnabled {
                    DatePicker("Час зважування", selection: timeBinding($settings.weighInReminderMinutes), displayedComponents: .hourAndMinute)
                }
                reminderToggle("Вода (кілька разів на день)", isOn: $settings.waterReminderEnabled)
                reminderToggle("Пропущене тренування", isOn: $settings.missedWorkoutReminderEnabled)
                reminderToggle("Нагадувати про резервну копію", isOn: $settings.backupReminderEnabled)
            } header: {
                Text("Нагадування")
            } footer: {
                if permissionDenied {
                    Text("Сповіщення вимкнені для додатку. Увімкни їх: Параметри → Сповіщення → Зал.")
                        .foregroundStyle(Theme.Palette.danger)
                } else {
                    Text("Лише локальні сповіщення на цьому телефоні.")
                }
            }

            Section {
                Toggle("Синхронізація з Apple Health", isOn: Binding(get: { healthEnabled }, set: { value in
                    if value {
                        Task {
                            do {
                                try await HealthService.requestAuthorization()
                                HealthService.isEnabled = true
                                healthEnabled = true
                            } catch {
                                healthMessage = error.localizedDescription
                                HealthService.isEnabled = false
                                healthEnabled = false
                            }
                        }
                    } else {
                        HealthService.isEnabled = false
                        healthEnabled = false
                    }
                }))
                if healthEnabled {
                    Button("Імпортувати вагу з Health (90 днів)") { importHealthWeights() }
                }
                if let healthMessage {
                    Text(healthMessage).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Apple Health (опційно)")
            } footer: {
                Text("Записує вагу і силові тренування в Health, читає вагу з розумних ваг. Потребує увімкнення HealthKit у Xcode (див. README).")
            }

            Section("Вигляд") {
                Picker("Тема", selection: Binding(get: { settings.theme }, set: { settings.theme = $0 })) {
                    Text("Системна").tag(AppTheme.system)
                    Text("Світла").tag(AppTheme.light)
                    Text("Темна").tag(AppTheme.dark)
                }
            }

            Section {
                Button("Скинути всі дані", role: .destructive) { confirmReset = true }
            } footer: {
                Text("Видаляє історію, профіль, фото і налаштування. Спершу зроби резервну копію.")
            }

            Section {
                LabeledContent("Версія", value: AppInfo.versionText)
            }
        }
        .navigationTitle("Налаштування")
        .onChange(of: settings.hapticsEnabled) { _, value in Haptics.isEnabled = value }
        .onDisappear {
            try? context.save()
            Task { await ReminderService.refresh(in: context) }
        }
        .confirmationDialog("Скинути всі дані?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Так, продовжити", role: .destructive) { confirmResetFinal = true }
        } message: {
            Text("Цю дію не можна скасувати.")
        }
        .alert("Точно видалити все?", isPresented: $confirmResetFinal) {
            Button("Видалити назавжди", role: .destructive) { DataReset.resetAll(in: context) }
            Button("Скасувати", role: .cancel) {}
        } message: {
            Text("Усі тренування, вага, заміри, фото і профіль буде видалено з телефону.")
        }
    }

    private func importHealthWeights() {
        Task {
            do {
                let since = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
                let samples = try await HealthService.weights(since: since)
                let existing = (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
                var added = 0
                for sample in samples where !existing.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: sample.date) }) {
                    context.insert(BodyWeightEntry(date: sample.date, weightKg: sample.kg))
                    added += 1
                }
                try? context.save()
                healthMessage = String(localized: "Імпортовано зважувань: \(added)")
            } catch {
                healthMessage = error.localizedDescription
            }
        }
    }

    private func reminderToggle(_ title: LocalizedStringResource, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(get: { isOn.wrappedValue }, set: { value in
            isOn.wrappedValue = value
            guard value else { return }
            Task {
                let granted = await NotificationService.requestAuthorizationIfNeeded()
                permissionDenied = !granted
                if !granted { isOn.wrappedValue = false }
            }
        })) {
            Text(title)
        }
    }

    private func plateBinding(_ plate: Double) -> Binding<Bool> {
        Binding(get: { settings.platesKg.contains(plate) }, set: { isOn in
            if isOn {
                settings.platesKg = (settings.platesKg + [plate]).sorted(by: >)
            } else {
                settings.platesKg.removeAll { $0 == plate }
            }
        })
    }

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }
}

enum AppInfo {
    static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }
}

/// "Скинути всі дані": wipes every model and stored photo, then starts fresh (onboarding).
@MainActor
enum DataReset {
    static func resetAll(in context: ModelContext) {
        // Children first (sets before workouts, days before programs) so batch deletes never hit live relationships.
        for model in SchemaV1.models.reversed() {
            try? context.delete(model: model)
        }
        for folder in PhotoStorage.Folder.allCases {
            if let url = try? PhotoStorage.directory(folder) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try? context.save()
        try? Persistence.bootstrap(context)
        SeedLoader.seedAll(context: context)
        NotificationService.center.removeAllPendingNotificationRequests()
    }
}
