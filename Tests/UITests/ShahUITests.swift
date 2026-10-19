import XCTest

/// Runs against `MockHealthService` (launch argument), never real Health data,
/// in Ukrainian so the labels are predictable.
final class ShahUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(skipOnboarding: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMockHealth", "-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA"]
        if skipOnboarding { app.launchArguments.append("-uiTestSkipOnboarding") }
        app.launch()
        return app
    }

    @MainActor
    func testOnboardingFlow() throws {
        let app = launch(skipOnboarding: false)

        app.buttons["onboarding.next"].tap()
        app.buttons["onboarding.allow"].tap()

        let increment = app.buttons["goal.increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 5))
        increment.tap()
        let goal = app.descendants(matching: .any)["goal.value"]
        XCTAssertEqual(goal.value as? String, "5,5\u{00A0}км")

        app.buttons["onboarding.start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["today.distance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Історія"].exists)
    }

    @MainActor
    func testTodayShowsDistanceAndSteps() throws {
        let app = launch(skipOnboarding: true)
        let distance = app.descendants(matching: .any)["today.distance"]
        XCTAssertTrue(distance.waitForExistence(timeout: 5))
        XCTAssertTrue(distance.label.contains("7,4"), distance.label)
        XCTAssertTrue(app.descendants(matching: .any)["today.steps"].exists)
    }

    @MainActor
    func testSwitchingHistoryPeriods() throws {
        let app = launch(skipOnboarding: true)
        app.tabBars.buttons["Історія"].tap()

        let title = app.staticTexts["history.periodTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let weekTitle = title.label

        let picker = app.segmentedControls["history.period"]
        picker.buttons["Місяць"].tap()
        XCTAssertNotEqual(title.label, weekTitle)

        picker.buttons["Рік"].tap()
        let year = String(Calendar.current.component(.year, from: .now))
        XCTAssertTrue(title.label.contains(year), title.label)

        picker.buttons["Тиждень"].tap()
        XCTAssertEqual(title.label, weekTitle)
        XCTAssertTrue(app.descendants(matching: .any)["history.streak"].exists)
    }
}
