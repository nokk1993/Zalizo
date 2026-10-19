import Foundation
import SwiftData
import UserNotifications
import ZalizoCore

/// Schedules all local reminders for the next two weeks. Called on launch, when settings change and after workouts.
/// Training reminders carry the concrete program day ("Сьогодні День A — Груди + Біцепс").
@MainActor
enum ReminderService {
    static let prefix = "reminder."

    static func refresh(in context: ModelContext, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard let settings = ProfileStore.settings(in: context),
              let profile = ProfileStore.profile(in: context), profile.onboardingCompleted else { return }
        let anyEnabled = settings.trainingReminderEnabled || settings.weighInReminderEnabled || settings.waterReminderEnabled
            || settings.missedWorkoutReminderEnabled || settings.backupReminderEnabled
        guard anyEnabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let calendar = Calendar.current
        var requests: [UNNotificationRequest] = []

        if settings.trainingReminderEnabled || settings.missedWorkoutReminderEnabled {
            for (date, dayName) in upcomingTrainingDays(in: context, now: now, calendar: calendar) {
                if settings.trainingReminderEnabled, let fire = time(settings.trainingReminderMinutes, on: date, calendar: calendar), fire > now {
                    requests.append(request("training.\(Int(date.timeIntervalSince1970))", at: fire, repeats: false,
                                            title: String(localized: "Сьогодні тренування"), body: dayName))
                }
                if settings.missedWorkoutReminderEnabled,
                   let nextDay = calendar.date(byAdding: .day, value: 1, to: date),
                   let fire = time(10 * 60, on: nextDay, calendar: calendar), fire > now {
                    requests.append(request("missed.\(Int(date.timeIntervalSince1970))", at: fire, repeats: false,
                                            title: String(localized: "Вчора було тренування за планом"),
                                            body: String(localized: "Нічого страшного — головне повернутися. Наступне тренування вже чекає.")))
                }
            }
        }
        if settings.weighInReminderEnabled {
            requests.append(dailyRequest("weigh", minutes: settings.weighInReminderMinutes,
                                         title: String(localized: "Час зважитися"),
                                         body: String(localized: "Зранку після туалету, до їжі — так найточніше.")))
        }
        if settings.waterReminderEnabled {
            for hour in [11, 13, 15, 17, 19] {
                requests.append(dailyRequest("water.\(hour)", minutes: hour * 60, title: String(localized: "Вода"),
                                             body: String(localized: "Склянка води — і відміть її в додатку.")))
            }
        }
        if settings.backupReminderEnabled, BackupReminder.isDue(lastBackup: settings.lastBackupAt, firstUse: profile.createdAt, now: now),
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), let fire = time(12 * 60, on: tomorrow, calendar: calendar) {
            requests.append(request("backup", at: fire, repeats: false, title: String(localized: "Резервна копія"),
                                    body: String(localized: "Минуло понад 2 тижні від останньої копії. Збережи дані: Профіль → Резервна копія.")))
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    /// Training dates in the next 14 days with the program day that falls on each.
    static func upcomingTrainingDays(in context: ModelContext, now: Date, calendar: Calendar) -> [(Date, String)] {
        guard let plan = TodayPlanner.plan(in: context, now: now) else { return [] }
        let days = plan.program.orderedDays
        let weekdays = ProfileStore.snapshot(in: context).trainingDays
        var result: [(Date, String)] = []
        var index = plan.next.dayIndex
        let start = calendar.startOfDay(for: plan.next.date)
        for offset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            guard weekdays.contains(Weekday.from(date: date, calendar: calendar)) else { continue }
            result.append((date, days[index % days.count].name))
            index += 1
        }
        return result
    }

    private static func time(_ minutes: Int, on date: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date)
    }

    private static func request(_ id: String, at date: Date, repeats: Bool, title: String, body: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNNotificationRequest(identifier: prefix + id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats))
    }

    private static func dailyRequest(_ id: String, minutes: Int, title: String, body: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = DateComponents(hour: minutes / 60, minute: minutes % 60)
        return UNNotificationRequest(identifier: prefix + id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
    }
}

enum BackupReminder {
    static let intervalDays = 14

    static func isDue(lastBackup: Date?, firstUse: Date, now: Date = .now) -> Bool {
        let reference = lastBackup ?? firstUse
        return now.timeIntervalSince(reference) >= Double(intervalDays) * 86_400
    }
}

/// Unlocks achievements and marks reached goals.
@MainActor
enum AchievementService {
    @discardableResult
    static func evaluate(in context: ModelContext) -> [AchievementKey] {
        let sessions = WorkoutService.finishedSessions(in: context)
        let snapshot = ProfileStore.snapshot(in: context)
        let dates = sessions.map(\.startedAt)
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let records = StatsStore.records(sessions, exercises: exercises)
        func best(_ slug: String) -> Double {
            records.flatMap { $0.exercises.filter { $0.slug == slug }.flatMap(\.sets) }.map(\.weight).max() ?? 0
        }
        refreshGoals(in: context)
        let goalsReached = ((try? context.fetch(FetchDescriptor<Goal>())) ?? []).filter { $0.achievedAt != nil }.count
        let input = Achievements.Input(
            workouts: sessions.count,
            bestWeekStreak: Achievements.bestWeekStreak(dates, target: snapshot.sessionsPerWeek),
            records: (try? context.fetchCount(FetchDescriptor<PersonalRecord>())) ?? 0,
            bodyWeightKg: ProfileStore.latestWeight(in: context)?.weightKg,
            bestBenchKg: best(KeyLift.benchPress.rawValue),
            bestSquatKg: best(KeyLift.squat.rawValue),
            totalTonnage: records.reduce(0) { $0 + $1.tonnage },
            deloads: sessions.filter(\.isDeload).count,
            goalsReached: goalsReached
        )
        let existing = Set(((try? context.fetch(FetchDescriptor<Achievement>())) ?? []).map(\.key))
        let new = Achievements.unlocked(input).filter { !existing.contains($0.rawValue) }
        for key in new {
            context.insert(Achievement(key: key.rawValue))
        }
        try? context.save()
        return AchievementKey.allCases.filter(new.contains)
    }

    /// Current value history for a goal.
    static func history(for goal: Goal, in context: ModelContext) -> [GoalProgress.Point] {
        switch goal.kind {
        case .bodyWeight:
            return ((try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []).map { .init(date: $0.date, value: $0.weightKg) }
        case .liftWeight:
            guard let slug = goal.exerciseSlug else { return [] }
            let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
            let records = StatsStore.records(WorkoutService.finishedSessions(in: context), exercises: exercises)
            let formula = ProfileStore.settings(in: context)?.oneRMFormula ?? .epley
            return StatsService.exerciseSeries(records, slug: slug, formula: formula).map { .init(date: $0.date, value: $0.estimatedOneRM) }
        case .workoutsPerMonth:
            let count = GoalProgress.workoutsThisMonth(WorkoutService.finishedSessions(in: context).map(\.startedAt))
            return [.init(date: .now, value: Double(count))]
        case .measurement:
            let kind = goal.measurementKindRaw
            return ((try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? [])
                .filter { $0.kindRaw == kind }
                .map { .init(date: $0.date, value: $0.valueCm) }
        }
    }

    static func status(for goal: Goal, in context: ModelContext) -> GoalProgress.Status {
        GoalProgress.status(start: goal.startValue, target: goal.targetValue, history: history(for: goal, in: context), deadline: goal.deadline)
    }

    static func refreshGoals(in context: ModelContext) {
        for goal in (try? context.fetch(FetchDescriptor<Goal>())) ?? [] where goal.achievedAt == nil {
            if status(for: goal, in: context).isAchieved {
                goal.achievedAt = .now
            }
        }
    }
}
