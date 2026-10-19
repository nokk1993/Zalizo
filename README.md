# Шаг

Скільки кілометрів ти пройшов сьогодні — за одну секунду. Дані з Apple Health
(iPhone + Apple Watch), жодних серверів, акаунтів чи реклами.

> **Статус: фаза 2 з 9 (каркас).** Повна інструкція встановлення для новачка
> з'явиться у фазі 7. Нижче — мінімум, щоб уже зараз перевірити збірку.

## Швидка перевірка збірки (Xcode 26.3, iOS 17+)

1. Відкрий `Config/Base.xcconfig` і заміни `com.yourname.shah` на свій
   унікальний ідентифікатор, наприклад `com.ivanpetrenko.shah`.
2. Відкрий `Shah.xcodeproj`.
3. Таргет **Shah** → *Signing & Capabilities* → *Team*: обери свій (Personal Team).
   Те саме для таргета **ShahWidgets**.
4. Обери свій iPhone угорі й натисни **Run** (⌘R).
5. Тести логіки: **Product → Test** (⌘U), або без Xcode:
   `cd Packages/ShahCore && swift test`.

Якщо Xcode каже, що твоя команда не підтримує якусь capability, у
`Config/Base.xcconfig` зміни `SHAH_CAPABILITIES = Full` на
`NoBackgroundDelivery` або `Basic`.

## Структура

```
App/            точка входу, AppModel, RootView
Features/       Today, History, Onboarding, Settings (екрани)
Services/       платформні сервіси застосунку (haptics, …)
DesignSystem/   кольори, типографіка, компоненти (спільні з віджетами)
Resources/      Assets, String Catalogs
Widgets/        WidgetKit extension
Tests/          UnitTests, UITests
Packages/ShahCore/   моделі, дні/DST/часові пояси, статистика, серії,
                     кеш, HealthKitService + MockHealthService, тести
Config/         xcconfig (Bundle ID), entitlements, Info.plist
Brand/          іконка, концепти, мокапи
Tools/          генератор .xcodeproj (для збірки не потрібен)
```
