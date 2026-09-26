import AppKit
import XCTest
@testable import MakeTask

@MainActor
final class ActiveNoteTests: XCTestCase {
    func testHideSelectsVisibleReplacementAndCommandsTargetIt() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let lists = makeLists(in: environment)
        environment.coordinator.noteDidBecomeActive(lists[2])
        environment.coordinator.hide(lists[2])
        XCTAssertEqual(environment.coordinator.activeListID, lists[1].id)
        environment.coordinator.sendKeyboardCommand(.search)
        XCTAssertEqual(environment.coordinator.noteKeyboardCommand?.listID, lists[1].id)
        XCTAssertTrue(lists[0].isHidden)
        XCTAssertTrue(lists[2].isHidden)
    }

    func testDeleteSelectsReplacementAndUndoRedoPreserveValidSelection() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let lists = makeLists(in: environment)
        let removedID = lists[2].id
        environment.coordinator.noteDidBecomeActive(lists[2])
        environment.coordinator.deleteList(lists[2])
        XCTAssertEqual(environment.coordinator.activeListID, lists[1].id)
        XCTAssertTrue(environment.coordinator.undoLastAction())
        XCTAssertNotNil(environment.coordinator.activeListID)
        XCTAssertTrue(environment.coordinator.redoLastAction())
        XCTAssertEqual(environment.coordinator.activeListID, lists[1].id)
        XCTAssertNotEqual(environment.coordinator.activeListID, removedID)
        environment.coordinator.hideAll()
    }

    func testHidingOrDeletingInactiveNoteKeepsActiveNote() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let lists = makeLists(in: environment)
        environment.coordinator.noteDidBecomeActive(lists[1])
        environment.coordinator.hide(lists[2])
        XCTAssertEqual(environment.coordinator.activeListID, lists[1].id)
        environment.coordinator.deleteList(lists[2])
        XCTAssertEqual(environment.coordinator.activeListID, lists[1].id)
    }

    func testNoVisibleNotesClearsSelectionAndIgnoresLateActivation() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let lists = makeLists(in: environment)
        environment.coordinator.noteDidBecomeActive(lists[2])
        environment.coordinator.hideAll()
        XCTAssertNil(environment.coordinator.activeListID)
        environment.coordinator.noteDidBecomeActive(lists[2])
        environment.coordinator.sendKeyboardCommand(.requestListDeletion)
        XCTAssertNil(environment.coordinator.activeListID)
        XCTAssertNil(environment.coordinator.noteKeyboardCommand)
        XCTAssertTrue(lists.allSatisfy(\.isHidden))
    }

    func testShowingNoteRestoresEmptySelection() throws {
        let environment = try TestEnvironment()
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let list = makeLists(in: environment)[0]
        environment.coordinator.hideAll()
        environment.coordinator.show(list)
        XCTAssertEqual(environment.coordinator.activeListID, list.id)
        XCTAssertFalse(list.isHidden)
    }

    func testHidingKeyPanelTransfersFocusToVisiblePanel() async throws {
        let environment = try TestEnvironment()
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let lists = makeLists(in: environment)
        environment.coordinator.show(lists[1])
        let other = TodoList(title: "Other visible", sortOrder: 3)
        environment.container.mainContext.insert(other)
        environment.coordinator.showAndActivate(other)
        environment.coordinator.showAndActivate(lists[2])
        try await Task.sleep(for: .milliseconds(150))
        let removedPanel = try XCTUnwrap(NSApp.keyWindow)
        XCTAssertEqual(environment.coordinator.activeListID, lists[2].id)
        environment.coordinator.hide(lists[2])
        XCTAssertEqual(environment.coordinator.activeListID, lists[1].id)
        XCTAssertFalse(NSApp.keyWindow === removedPanel)
        XCTAssertEqual((NSApp.keyWindow?.windowController as? NoteWindowController)?.list.id, lists[1].id)
    }

    func testDeletingListFromQuickAddDoesNotStealItsFocus() async throws {
        let environment = try TestEnvironment()
        defer {
            environment.coordinator.dismissQuickAdd()
            environment.coordinator.hideAll()
            environment.cleanUp()
        }
        let lists = makeLists(in: environment)
        environment.coordinator.show(lists[1])
        environment.coordinator.showAndActivate(lists[2])
        try await Task.sleep(for: .milliseconds(150))
        environment.coordinator.presentQuickAdd()
        try await Task.sleep(for: .milliseconds(150))
        let quickAdd = try XCTUnwrap(NSApp.keyWindow)
        XCTAssertTrue(quickAdd.windowController is QuickAddWindowController)
        environment.coordinator.deleteList(lists[2])
        XCTAssertEqual(environment.coordinator.activeListID, lists[1].id)
        XCTAssertTrue(NSApp.keyWindow === quickAdd)
    }

    private func makeLists(in environment: TestEnvironment) -> [TodoList] {
        let lists = [
            TodoList(title: "Hidden", sortOrder: 0, isHidden: true),
            TodoList(title: "First visible", sortOrder: 1),
            TodoList(title: "Last visible", sortOrder: 2)
        ]
        lists.forEach(environment.container.mainContext.insert)
        return lists
    }
}
