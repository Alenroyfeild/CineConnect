import XCTest

@MainActor
final class AssignmentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        // Minimal smoke test: proves the UI-test target builds and can drive
        // the app process. Critical-path UI tests (search, detail, logout)
        // land in Phase 9 once the app exposes stable accessibility identifiers.
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
