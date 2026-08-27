import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class PersistenceTests: XCTestCase {
    func testDeletingListCascadesToTasksAndSubtasks() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let list = TodoList(title: "Temporary")
        let task = TodoTask(title: "Parent task", list: list)
        let subtask = TodoSubtask(title: "Child task", task: task)
        context.insert(list)
        context.insert(task)
        context.insert(subtask)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoList>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoSubtask>()), 1)

        context.delete(list)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoList>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoSubtask>()), 0)
    }

    func testBackupSnapshotPreservesOrderingAndWindowState() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let list = TodoList(
            title: "University",
            color: .indigo,
            sortOrder: 3,
            windowX: 90,
            windowTop: 700,
            windowWidth: 410,
            windowHeight: 520,
            isCollapsed: true,
            isCompletedSectionCollapsed: true,
            isHidden: true,
            windowMode: .alwaysOnTop
        )
        let second = TodoTask(title: "Second", sortOrder: 2, list: list)
        let first = TodoTask(title: "First", sortOrder: 1, list: list)
        context.insert(list)
        context.insert(second)
        context.insert(first)
        try context.save()
        environment.settings.defaultListID = list.id

        let document = try environment.coordinator.makeBackupDocument()
        let record = try XCTUnwrap(document.lists.first)

        XCTAssertEqual(record.title, "University")
        XCTAssertEqual(record.colorRawValue, NoteColor.indigo.rawValue)
        XCTAssertEqual(record.tasks.map(\.title), ["First", "Second"])
        XCTAssertEqual(record.windowX, 90)
        XCTAssertEqual(record.windowTop, 700)
        XCTAssertEqual(record.windowWidth, 410)
        XCTAssertEqual(record.windowHeight, 520)
        XCTAssertTrue(record.isCollapsed)
        XCTAssertTrue(record.isCompletedSectionCollapsed)
        XCTAssertTrue(record.isHidden)
        XCTAssertEqual(record.windowModeRawValue, WindowMode.alwaysOnTop.rawValue)
        XCTAssertEqual(document.defaultListID, list.id)
    }

    func testStaleDefaultIdentifiersAreExcludedFromBackup() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        environment.settings.defaultListID = UUID()
        environment.settings.lastQuickCaptureListID = UUID()

        let document = try environment.coordinator.makeBackupDocument()

        XCTAssertNil(document.defaultListID)
        XCTAssertNil(document.lastQuickCaptureListID)
        XCTAssertNoThrow(try document.validate())
    }
}
