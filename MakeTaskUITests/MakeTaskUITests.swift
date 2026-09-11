import XCTest

final class MakeTaskUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["MAKETASK_UI_TESTING"] = "1"
        app.launch()
        app.activate()

        XCTAssertTrue(
            newTaskField.waitForExistence(timeout: 5),
            "The seeded UI test note did not appear."
        )
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testCreatesAndCompletesTask() {
        let taskTitle = "Test task"

        replaceText(in: newTaskField, with: taskTitle)
        newTaskField.typeKey(.return, modifierFlags: [])

        let completeButton = app.buttons["Complete \(taskTitle)"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 3))
        completeButton.click()

        XCTAssertTrue(
            app.buttons["Mark \(taskTitle) incomplete"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.buttons["Hide completed tasks"].exists)
    }

    func testCollapseExpandAndHideRecoveryShortcuts() {
        app.typeKey("m", modifierFlags: .command)
        XCTAssertTrue(newTaskField.waitForNonExistence(timeout: 2))
        XCTAssertTrue(staticText(withValue: "UI Test List").exists)

        app.typeKey("m", modifierFlags: .command)
        XCTAssertTrue(newTaskField.waitForExistence(timeout: 2))

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(newTaskField.waitForNonExistence(timeout: 2))

        performMenuItem("Show or Hide All Notes", in: "Note")
        XCTAssertTrue(newTaskField.waitForExistence(timeout: 2))
    }

    func testQuickAddCreatesTaskWithoutMouse() {
        let taskTitle = "Captured from shortcut"

        performMenuItem("Quick Add", in: "Note")
        let quickAddField = app.textFields["quick-add.task-field"]
        XCTAssertTrue(quickAddField.waitForExistence(timeout: 2))

        replaceText(in: quickAddField, with: taskTitle)
        quickAddField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(quickAddField.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Complete \(taskTitle)"].waitForExistence(timeout: 3))
    }

    func testQuickAddDeletesSelectedListWithConfirmation() {
        performMenuItem("Quick Add", in: "Note")

        let deleteListButton = app.buttons["quick-add.delete-list"]
        XCTAssertTrue(deleteListButton.waitForExistence(timeout: 2))
        deleteListButton.click()

        XCTAssertTrue(
            app.buttons["quick-add.confirm-delete-list"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.staticTexts["quick-add.delete-list-warning"].exists)
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            app.textFields["quick-add.list-name-field"].waitForExistence(timeout: 2),
            "Deleting the only list should switch Quick Add to first-list creation."
        )
    }

    func testKeyboardSelectionEditingUndoAndRedo() {
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        let titleField = app.textFields["task.title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 2))

        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(app.buttons["Mark Alpha Task incomplete"].waitForExistence(timeout: 2))

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Complete Alpha Task"].waitForExistence(timeout: 2))

        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons["Mark Alpha Task incomplete"].waitForExistence(timeout: 2))
    }

    func testNewListShortcutStartsInlineRename() {
        app.typeKey("n", modifierFlags: [.command, .shift])

        let listNameField = app.textFields["note.list-name-field"]
        XCTAssertTrue(listNameField.waitForExistence(timeout: 2))
        replaceText(in: listNameField, with: "Another Note")
        listNameField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(staticText(withValue: "Another Note").waitForExistence(timeout: 2))
    }

    func testDueDateControlKeysDoNotCompleteOrEditParentTask() {
        staticText(withValue: "Alpha Task").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let dueToggle = app.checkBoxes["task.due-toggle"]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 2))
        dueToggle.click()
        let datePicker = app.datePickers["task.due-date"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 2))
        datePicker.click()
        app.typeKey(.upArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.space, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.buttons["Complete Alpha Task"].exists)
        XCTAssertFalse(app.buttons["Mark Alpha Task incomplete"].exists)
        XCTAssertTrue(app.buttons["Complete Beta Task"].exists)
        XCTAssertFalse(app.textFields["task.title-field"].exists)
        XCTAssertTrue(dueToggle.exists)
        XCTAssertTrue(newTaskField.exists)
    }

    func testSaveFailureIsVisibleFromNoteWithoutOpeningSettings() {
        app.terminate()
        app.launchEnvironment["MAKETASK_UI_TEST_SAVE_FAILURE"] = "1"
        app.launch()
        app.activate()
        let indicator = app.buttons["runtime.issue-indicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 5))
        indicator.click()
        XCTAssertTrue(app.staticTexts["runtime.save-warning"].waitForExistence(timeout: 2))
        let retry = app.buttons["runtime.retry-save"]
        XCTAssertTrue(retry.exists)
        retry.click()
        XCTAssertTrue(app.staticTexts["runtime.save-warning"].exists,
                      "An unsuccessful retry must keep the save failure visible.")
        XCTAssertTrue(newTaskField.exists)
    }

    private var newTaskField: XCUIElement {
        app.textFields["note.new-task-field"]
    }

    private func staticText(withValue value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "value == %@", value)).firstMatch
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        element.click()
        element.typeText("x")
        element.typeKey("a", modifierFlags: .command)
        for character in text {
            element.typeText(String(character))
        }
    }

    private func performMenuItem(_ itemTitle: String, in menuTitle: String) {
        let menu = app.menuBars.menuBarItems[menuTitle]
        XCTAssertTrue(menu.waitForExistence(timeout: 2))
        menu.click()

        // The status menu can expose the same action title as the app menu.
        let item = menu.menuItems[itemTitle]
        XCTAssertTrue(item.waitForExistence(timeout: 2))
        item.click()
    }
}
