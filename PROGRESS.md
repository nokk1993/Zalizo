# Стан роботи (для продовження в новій сесії Claude Code)

Інструкції проєкту: `CLAUDE.md`. Тут записано, що вже зроблено і які рішення ухвалено.

## Відповіді власника (розділ 1.4)
- Mac з Xcode 26.3: є.
- Акаунт: **безкоштовний Apple ID (Personal Team)**.
- Модель iPhone: не вказана (iOS 26.7.1).

## Зроблено
- **Етап 1 (каркас)**: власник зібрав і встановив на iPhone, працює.
- **Етап 2 (розрахунки)**: `Packages/ZalizoCore/Sources/ZalizoCore/Calculations/` — BodyMetrics, NutritionCalculator, WeightTrend, AdaptiveCalories, StrengthMath (OneRM, WeightRounding, PlateCalculator, WarmupGenerator, Volume). 54 тести зелені (Swift 6.2, Linux).
- **Етап 3 (профіль і онбординг)**: `ZalizoCore/Profile/ProfileSnapshot.swift` (ProfileSnapshot, PlanCalculator.summary/changes, ProgramCatalog, KeyLift, LiftResult); `Zalizo/Services/ProfileStore.swift`; `Features/Onboarding/*` (11 кроків, продовження з місця зупинки, «Пропустити» → дефолти); `Features/Profile/*` (Мої дані з екраном «Що зміниться», Норми і прогноз, Пройти анкету заново). **Ще не зібрано в Xcode.**
- **Етап 4 (бібліотека вправ)**: seed 71 вправи (`Tools/seed/exercises_seed.py` → `Resources/Seed/exercises.json`, версія seed 1), 142 фото (`Assets.xcassets/Exercises`, `Tools/seed/import_exercise_images.py`), `SeedLoader` (не перезаписує правки), `PhotoStorage`, `BodyMapView` (схема м'язів спереду/ззаду), екрани: бібліотека (пошук, фільтри, обране, режим вибору `onPick`), картка вправи, власна вправа з фото. Тести seed читають реальний JSON. **Ще не зібрано в Xcode.**
- **Етап 5 (програми)**: 5 програм (`Tools/seed/programs_seed.py` → `programs.json`, друкує таблицю об'єму), `ProgramStore` (активна програма, копія, нова, автозаміна вправ `ExerciseSubstitution`), екрани програми/дня/вправи/вибору, таблиця об'єму. Відоме відхилення: у «Маса 3 дні» квадрицепс ≈ 7 підходів/тиждень (програма задана власником; тест це враховує).
- **Етапи 6–7 (тренування + прогресія + Сьогодні)**: ядро `Training/` (ProgressionEngine, Calibration, DeloadAdvisor, WellnessAdvisor, ExerciseBests, RestTimer, WorkoutStats, TrainingSchedule, SessionEstimate); `WorkoutService`, `TodayPlanner`, `NotificationService`; екрани `Features/Workout/*` (режим тренування, таймер, калькулятор дисків, розминка, підсумок) і `Features/Today/TodayView.swift`. Розвантаження: `blockStartDate` у майбутньому = тиждень розвантаження. **Ще не зібрано в Xcode.**
- **Етап 8 (прогрес)**: ядро `Stats/StatsService.swift` (серії по вправі, рекорди RM, огляд, тижні, календар, об'єм по м'язах); `StatsStore`; екрани `Features/Progress/*` (дашборд з періодом, графік ваги з середнім/ціллю/прогнозом, заміри, фото з камерою і порівнянням повзунком, сила по вправах, історія). **Ще не зібрано в Xcode.**
- **Етап 9 (харчування)**: `Tools/seed/nutrition_seed.py` → `foods.json` (95 продуктів) і `menus.json` (6 шаблонів); ядро `Nutrition/MenuBuilder.swift` (масштабування, заміни за алергіями/бюджетом, 3–6 прийомів, список покупок); `NutritionStore`; `Features/Nutrition/*` (щоденник з кільцями, вода, меню, норми, поради, адаптивна корекція).
- **Етап 10 (цілі, досягнення, нагадування, база знань, швидкий запис)**: `Tools/seed/knowledge_seed.py` → `knowledge.json` (15 статей); ядро `QuickLog/QuickLogParser.swift` (15 варіантів написання в тестах), `Goals/Goals.swift`; `ReminderService` (локальні сповіщення на 14 днів з назвою дня програми), `AchievementService`; екрани `SettingsView` (усі налаштування 6.11 крім фунтів), `GoalsView`, `QuickLogView`, `KnowledgeViews`.
- **Етап 11 (бекап)**: ядро `Backup/BackupFile.swift` (schemaVersion, усі секції опційні при читанні, дати як секунди — точний round trip, CSV); `BackupService` (експорт, імпорт «замінити все»/«об'єднати», фото base64 у файлі); `BackupView`; тест експорт → скидання → імпорт.

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
