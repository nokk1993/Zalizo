import SwiftUI
import ZalizoCore

// User-facing Ukrainian titles for domain enums (extracted into Localizable.xcstrings).

extension Sex {
    var title: LocalizedStringResource {
        switch self {
        case .male: "Чоловік"
        case .female: "Жінка"
        }
    }
}

extension ExperienceLevel {
    var title: LocalizedStringResource {
        switch self {
        case .beginner: "Новачок (до 1 року)"
        case .intermediate: "Середній (1–3 роки)"
        case .advanced: "Досвідчений (3+ роки)"
        }
    }
}

extension TrainingGoal {
    var title: LocalizedStringResource {
        switch self {
        case .muscleGain: "Набір маси"
        case .strength: "Сила"
        case .recomposition: "Рекомпозиція"
        case .maintenance: "Підтримка"
        }
    }
}

extension ActivityLevel {
    var title: LocalizedStringResource {
        switch self {
        case .sedentary: "Сидяча робота"
        case .moderate: "Помірна активність"
        case .physical: "Фізична робота"
        }
    }
}

extension Equipment {
    var title: LocalizedStringResource {
        switch self {
        case .barbell: "Штанга"
        case .dumbbells: "Гантелі"
        case .cables: "Блоки / кросовер"
        case .machines: "Тренажери"
        case .pullUpBar: "Турнік"
        case .dipBars: "Бруси"
        case .adjustableBench: "Лава з нахилом"
        case .ezBar: "EZ-гриф"
        case .bodyweight: "Власна вага"
        }
    }
}

extension InjuryArea {
    var title: LocalizedStringResource {
        switch self {
        case .lowerBack: "Поперек"
        case .knees: "Коліна"
        case .shoulders: "Плечі"
        case .elbows: "Лікті"
        case .wrists: "Зап'ястя"
        }
    }
}

extension MuscleGroup {
    var title: LocalizedStringResource {
        switch self {
        case .chest: "Груди"
        case .back: "Спина"
        case .shoulders: "Плечі"
        case .biceps: "Біцепс"
        case .triceps: "Трицепс"
        case .forearms: "Передпліччя"
        case .quads: "Квадрицепс"
        case .hamstrings: "Біцепс стегна"
        case .glutes: "Сідниці"
        case .calves: "Литки"
        case .abs: "Прес"
        case .traps: "Трапеції"
        }
    }
}

extension DietExclusion {
    var title: LocalizedStringResource {
        switch self {
        case .dairy: "Молочне"
        case .gluten: "Глютен"
        case .pork: "Свинина"
        case .fish: "Риба"
        case .eggs: "Яйця"
        case .nuts: "Горіхи"
        case .lactose: "Лактоза"
        }
    }
}

extension FoodBudget {
    var title: LocalizedStringResource {
        switch self {
        case .economy: "Економ"
        case .medium: "Середній"
        }
    }
}

extension MeasurementKind {
    var title: LocalizedStringResource {
        switch self {
        case .chest: "Груди"
        case .waist: "Талія"
        case .hips: "Стегна (обхват)"
        case .bicepsLeft: "Біцепс лівий"
        case .bicepsRight: "Біцепс правий"
        case .thigh: "Стегно"
        case .calf: "Гомілка"
        case .neck: "Шия"
        }
    }
}

extension Weekday {
    var shortTitle: LocalizedStringResource {
        switch self {
        case .monday: "Пн"
        case .tuesday: "Вт"
        case .wednesday: "Ср"
        case .thursday: "Чт"
        case .friday: "Пт"
        case .saturday: "Сб"
        case .sunday: "Нд"
        }
    }
}

extension KeyLift {
    var title: LocalizedStringResource {
        switch self {
        case .benchPress: "Жим штанги лежачи"
        case .squat: "Присідання зі штангою"
        case .romanianDeadlift: "Румунська станова тяга"
        case .overheadPress: "Жим штанги стоячи"
        case .barbellRow: "Тяга штанги в нахилі"
        }
    }
}

extension ExperienceLevel {
    var subtitle: LocalizedStringResource {
        switch self {
        case .beginner: "Тренуюсь нерегулярно або менше року"
        case .intermediate: "Регулярно тренуюсь, знаю базову техніку"
        case .advanced: "Довго тренуюсь, прогрес уже повільний"
        }
    }
}

extension TrainingGoal {
    var subtitle: LocalizedStringResource {
        switch self {
        case .muscleGain: "Профіцит калорій, ріст м'язів і ваги"
        case .strength: "Більше сили в базових вправах"
        case .recomposition: "Менше жиру, більше м'язів, вага майже не змінюється"
        case .maintenance: "Зберегти форму"
        }
    }

    var systemImage: String {
        switch self {
        case .muscleGain: "arrow.up.right.circle"
        case .strength: "dumbbell"
        case .recomposition: "arrow.triangle.2.circlepath"
        case .maintenance: "equal.circle"
        }
    }
}

extension ActivityLevel {
    var subtitle: LocalizedStringResource {
        switch self {
        case .sedentary: "Офіс, навчання, мало кроків (коефіцієнт 1,375)"
        case .moderate: "Багато ходжу, частково на ногах (коефіцієнт 1,55)"
        case .physical: "Фізична праця більшу частину дня (коефіцієнт 1,725)"
        }
    }

    var systemImage: String {
        switch self {
        case .sedentary: "chair.lounge"
        case .moderate: "figure.walk"
        case .physical: "hammer"
        }
    }
}

extension Equipment {
    var systemImage: String {
        switch self {
        case .barbell: "figure.strengthtraining.traditional"
        case .dumbbells: "dumbbell"
        case .cables: "cable.connector"
        case .machines: "gearshape.2"
        case .pullUpBar: "figure.climbing"
        case .dipBars: "figure.cross.training"
        case .adjustableBench: "bed.double"
        case .ezBar: "line.diagonal"
        case .bodyweight: "figure.core.training"
        }
    }
}

extension InjuryArea {
    var systemImage: String {
        switch self {
        case .lowerBack: "figure.walk.motion"
        case .knees: "figure.run"
        case .shoulders: "figure.arms.open"
        case .elbows: "hand.raised"
        case .wrists: "hand.point.up.left"
        }
    }
}

extension FoodBudget {
    var subtitle: LocalizedStringResource {
        switch self {
        case .economy: "Крупи, яйця, курка, сир, бобові"
        case .medium: "Плюс риба, яловичина, горіхи, грецький йогурт"
        }
    }
}

/// Titles of built-in programs by their stable slug.
enum ProgramTitles {
    static func title(slug: String) -> LocalizedStringResource {
        switch slug {
        case ProgramCatalog.massSplit3: "Маса 3 дні: Спліт"
        case ProgramCatalog.fullBody3: "Full Body 3 дні"
        case ProgramCatalog.upperLower4: "Upper/Lower 4 дні"
        case ProgramCatalog.pushPullLegs3: "Push/Pull/Legs 3 дні"
        case ProgramCatalog.pushPullLegs6: "Push/Pull/Legs 6 днів"
        default: "Власна програма"
        }
    }
}

extension PlanChange.Field {
    var title: LocalizedStringResource {
        switch self {
        case .kcal: "Калорії (день відпочинку)"
        case .trainingDayKcal: "Калорії (тренувальний день)"
        case .protein: "Білок"
        case .fat: "Жири"
        case .carbs: "Вуглеводи"
        case .water: "Вода"
        case .targetWeight: "Цільова вага"
        case .weeklyRate: "Темп набору"
        case .forecastWeeks: "Прогноз"
        case .program: "Рекомендована програма"
        }
    }

    /// Unit suffix for old → new values.
    var unit: LocalizedStringResource {
        switch self {
        case .kcal, .trainingDayKcal: "ккал"
        case .protein, .fat, .carbs: "г"
        case .water: "мл"
        case .targetWeight: "кг"
        case .weeklyRate: "кг/тижд"
        case .forecastWeeks: "тижн."
        case .program: ""
        }
    }
}
