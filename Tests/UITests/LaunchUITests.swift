import XCTest

/// Runs against `MockHealthService` (launch argument), never real Health data.
final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTodayShowsDistance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMockHealth", "-uiTestSkipOnboarding"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.distance"].waitForExistence(timeout: 5))
    }
}
