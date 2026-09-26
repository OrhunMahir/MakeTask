import XCTest

final class WelcomeUITests: XCTestCase {
    func testFirstLaunchPrivacyAndCreatingFirstList() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["MAKETASK_UI_TESTING"] = "1"
        app.launchEnvironment["MAKETASK_UI_TEST_WELCOME"] = "1"
        app.launch()
        defer { app.terminate() }
        app.activate()
        let name = app.textFields["welcome.list-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let welcome = XCTAttachment(screenshot: app.screenshot())
        welcome.name = "First launch"
        welcome.lifetime = .keepAlways
        add(welcome)
        app.descendants(matching: .any)["welcome.privacy-policy"].click()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "MakeTask Privacy Policy")).firstMatch.waitForExistence(timeout: 3))
        let privacy = XCTAttachment(screenshot: app.screenshot())
        privacy.name = "Privacy policy"
        privacy.lifetime = .keepAlways
        add(privacy)
        app.buttons["privacy.done"].click()
        name.click()
        name.typeKey("a", modifierFlags: .command)
        for character in "Books" {
            name.typeText(String(character))
        }
        XCTAssertEqual(name.value as? String, "Books")
        app.buttons["welcome.create-list"].click()
        XCTAssertTrue(name.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.textFields["note.new-task-field"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND (value == %@ OR label == %@)",
            "note.title.", "Books", "Books"
        )).firstMatch.waitForExistence(timeout: 3), app.debugDescription)
    }
}
