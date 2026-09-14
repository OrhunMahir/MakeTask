import AppKit
import XCTest

/// Uses the production borderless FloatingNotePanel, not UITestHostView.
final class NativeNoteSafetyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["MAKETASK_UI_TESTING"] = "1"
        app.launchEnvironment["MAKETASK_UI_TEST_NATIVE_NOTES"] = "1"
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    private func launch() {
        app.launch()
        app.activate()
        XCTAssertTrue(app.buttons["Complete Alpha Task"].waitForExistence(timeout: 5))
    }

    func testDeleteFromHeaderCancelConfirmAndUndoRestoresNativeNote() {
        launch()
        app.descendants(matching: .any).matching(identifier: "note.options").firstMatch.click()
        app.menuItems["Delete List"].click()
        XCTAssertTrue(app.dialogs.buttons["Cancel"].waitForExistence(timeout: 2))
        app.dialogs.buttons["Cancel"].click()
        XCTAssertTrue(app.buttons["Complete Alpha Task"].exists)

        app.descendants(matching: .any).matching(identifier: "note.options").firstMatch.click()
        app.menuItems["Delete List"].click()
        confirmDeleteAndUndo()
    }

    func testDeleteShortcutAndUndoRestoresNativeNote() {
        launch()
        app.typeKey(.delete, modifierFlags: .command)
        confirmDeleteAndUndo()
    }

    @MainActor
    func testStatusMenuUndoRestoresDeletedNativeNote() throws {
        launch()
        let status = app.descendants(matching: .statusItem).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 2))
        // A crowded menu bar can place a status item underneath the camera
        // housing. Accessibility still reports it, but physical clicks miss it.
        if let primary = NSScreen.screens.first {
            let center = NSPoint(x: status.frame.midX, y: primary.frame.maxY - status.frame.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }),
               let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea,
               center.y >= screen.frame.maxY - screen.safeAreaInsets.top {
                try XCTSkipIf(!left.contains(center) && !right.contains(center),
                              "The status item is obscured by this Mac's camera housing; retry with more menu-bar space or a display without a notch.")
            }
        }
        app.typeKey(.delete, modifierFlags: .command)
        XCTAssertTrue(app.dialogs.buttons["Delete List"].waitForExistence(timeout: 2))
        app.dialogs.buttons["Delete List"].click()
        XCTAssertTrue(app.buttons["Complete Alpha Task"].waitForNonExistence(timeout: 3))
        status.click()
        let undo = app.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Undo Last Action")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        XCTAssertTrue(undo.isEnabled)
        // Click the item in the open status menu without traversing app menus.
        undo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(app.buttons["Complete Alpha Task"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Complete Beta Task"].exists)
    }

    func testClearCompletedAndUndoPreservesOtherTasks() {
        launch()
        app.buttons["Complete Alpha Task"].click()
        XCTAssertTrue(app.buttons["Mark Alpha Task incomplete"].waitForExistence(timeout: 2))
        app.typeKey(.delete, modifierFlags: [.command, .option])
        let confirm = app.dialogs.buttons["Clear Completed Tasks"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.click()
        XCTAssertTrue(app.buttons["Mark Alpha Task incomplete"].waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Complete Beta Task"].exists)
        undoFromMenu()
        XCTAssertTrue(app.buttons["Mark Alpha Task incomplete"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Complete Beta Task"].exists)
    }

    func testFailedQuitCanBeCancelledThenExplicitlyDiscarded() {
        app.launchEnvironment["MAKETASK_UI_TEST_SAVE_FAILURE"] = "1"
        launch()
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.dialogs.buttons["Quit Without Saving"].waitForExistence(timeout: 3))
        app.dialogs.buttons["Cancel"].click()
        XCTAssertTrue(app.buttons["Complete Alpha Task"].exists)
        XCTAssertTrue(app.buttons["runtime.issue-indicator"].exists)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.dialogs.buttons["Quit Without Saving"].waitForExistence(timeout: 3))
        app.dialogs.buttons["Quit Without Saving"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    private func confirmDeleteAndUndo() {
        XCTAssertTrue(app.dialogs.buttons["Delete List"].waitForExistence(timeout: 2))
        app.dialogs.buttons["Delete List"].click()
        XCTAssertTrue(app.buttons["Complete Alpha Task"].waitForNonExistence(timeout: 3))
        undoFromMenu()
        XCTAssertTrue(app.buttons["Complete Alpha Task"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Complete Beta Task"].exists)
    }

    private func undoFromMenu() {
        let noteMenu = app.menuBars.menuBarItems["Note"]
        noteMenu.click()
        let undo = noteMenu.menuItems["Undo Last MakeTask Action"]
        XCTAssertTrue(undo.isEnabled, "Undo must become enabled after a confirmed deletion")
        undo.click()
    }
}
