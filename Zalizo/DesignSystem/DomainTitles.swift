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
