import XCTest

final class ForgeTextShellUITests: XCTestCase {
    @MainActor
    func testStudioShellExposesPrimaryNavigation() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES"
        ]
        app.launchEnvironment["FORGETEXT_UI_TESTING"] = "1"
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["forgetext.sidebar.explorer"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["forgetext.sidebar.search"].exists)
        XCTAssertTrue(app.buttons["forgetext.sidebar.sourceControl"].exists)
        XCTAssertTrue(app.buttons["forgetext.sidebar.workbench"].exists)
    }
}
