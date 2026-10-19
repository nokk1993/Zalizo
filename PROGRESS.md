# Стан роботи (для продовження в новій сесії Claude Code)

Інструкції проєкту: `CLAUDE.md`. Тут записано, що вже зроблено і які рішення ухвалено.

## Відповіді власника (розділ 1.4)
- Mac з Xcode 26.3: є.
- Акаунт: **безкоштовний Apple ID (Personal Team)**.
- Модель iPhone: не вказана (iOS 26.7.1).

## Зроблено
- **Етап 1 (каркас)**: власник зібрав і встановив на iPhone, працює.
- **Етап 2 (розрахунки)**: `Packages/ZalizoCore/Sources/ZalizoCore/Calculations/` — BodyMetrics, NutritionCalculator, WeightTrend, AdaptiveCalories, StrengthMath (OneRM, WeightRounding, PlateCalculator, WarmupGenerator, Volume). 54 тести зелені (Swift 6.2, Linux).

## Ухвалені рішення
- Bundle ID: `ua.zalizo.app.b82a66`. Він стабільний, без персональних даних, **не змінювати**.
- `.xcodeproj` написаний вручну, без XcodeGen. Використовуються синхронізовані папки (objectVersion 77), тож нові файли в `Zalizo/` і `ZalizoTests/` підхоплюються автоматично.
- Уся чиста логіка (розрахунки, ProgressionEngine, парсер, бекап-DTO, статистика) живе в локальному пакеті `Packages/ZalizoCore`: тільки Foundation, без UI. Тести на Swift Testing, запуск через `swift test`. Це не стороння залежність.
- Схема SwiftData v1 (`Zalizo/Models/SchemaV1.swift`) описана одразу повністю. Будь-яка зміна моделей іде через `SchemaV2` і стадію в `ZalizoMigrationPlan`, моделі v1 не редагувати.
- Enum-поля в моделях зберігаються як raw-рядки з типізованими accessor-ами. Посилання на вправи робляться через `slug`, а не через relationship.
- Меню, довідник продуктів і статті бази знань — статичні JSON у бандлі (не в БД). Вправи і програми сідяться в БД з версіонуванням (`AppSettings.exercisesSeedVersion` / `programsSeedVersion`).
- Картинки вправ: `yuhonas/free-exercise-db`, ліцензія **Unlicense** (суспільне надбання). Брати тільки потрібні вправи, стиснути до ширини ~800 px, додати `ASSETS_LICENSE.md`.
- Default actor isolation — nonisolated (класичний Swift 6). View-моделі позначаються `@MainActor` явно.
- Capabilities для Personal Team: iCloud, push і App Groups не використовувати. HealthKit, Live Activity і віджети — опційно, перевірити в Xcode на етапі 12.

## Репозиторій
GitHub: `nokk1993/zalizo` (приватний), гілка `main`.
