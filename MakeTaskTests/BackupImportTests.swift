import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class BackupImportTests: XCTestCase {
    func testImportAddsFreshObjectsAndPreservesExistingData() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext

        let existing = TodoList(title: "Release", color: .yellow, sortOrder: 0)
        let existingTask = TodoTask(title: "Existing task", sortOrder: 0, list: existing)
        context.insert(existing)
        context.insert(existingTask)
        try context.save()
        environment.settings.defaultListID = existing.id

        let backupListID = UUID()
        let backupTaskID = UUID()
        let backupSubtaskID = UUID()
        let document = BackupFixtures.document(
            listID: backupListID,
            taskID: backupTaskID,
            subtaskID: backupSubtaskID,
            title: "Release",
            windowWidth: 80,
            windowHeight: 5_000
        )

        let result = try environment.coordinator.importBackup(document)
        let lists = try context.fetch(
            FetchDescriptor<TodoList>(sortBy: [SortDescriptor(\TodoList.sortOrder)])
        )

        XCTAssertEqual(result, MakeTaskBackupImportResult(listCount: 1, taskCount: 1, subtaskCount: 1))
        XCTAssertEqual(lists.count, 2)
        XCTAssertEqual(lists[0].id, existing.id)
        XCTAssertEqual(lists[0].tasks.first?.title, "Existing task")

        let imported = try XCTUnwrap(lists.first { $0.id != existing.id })
        XCTAssertEqual(imported.title, "Release (Imported)")
        XCTAssertNotEqual(imported.id, backupListID)
        XCTAssertEqual(imported.noteColor, .teal)
        XCTAssertEqual(imported.windowMode, .normal)
        XCTAssertEqual(imported.windowWidth, NoteWindowMetrics.minimumWidth)
        XCTAssertEqual(imported.windowHeight, 2_000)
        XCTAssertTrue(imported.isCollapsed)
        XCTAssertTrue(imported.isCompletedSectionCollapsed)
        XCTAssertTrue(imported.isHidden)

        let importedTask = try XCTUnwrap(imported.tasks.first)
        XCTAssertNotEqual(importedTask.id, backupTaskID)
        XCTAssertEqual(importedTask.title, "Publish MakeTask")
        XCTAssertEqual(importedTask.notes, "Keep the release fully local.")
        XCTAssertEqual(importedTask.dueDate, BackupFixtures.date)
        XCTAssertEqual(importedTask.priorityLevel, .high)
        XCTAssertFalse(importedTask.isCompleted)

        let importedSubtask = try XCTUnwrap(importedTask.subtasks.first)
        XCTAssertNotEqual(importedSubtask.id, backupSubtaskID)
        XCTAssertEqual(importedSubtask.title, "Run smoke tests")
        XCTAssertTrue(importedSubtask.isCompleted)

        XCTAssertEqual(environment.settings.defaultListID, existing.id)
        XCTAssertEqual(environment.settings.lastQuickCaptureListID, imported.id)
    }

    func testImportUsesBackupDefaultWhenNoDefaultExists() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let document = BackupFixtures.document()

        _ = try environment.coordinator.importBackup(document)
        let imported = try XCTUnwrap(
            try environment.container.mainContext.fetch(FetchDescriptor<TodoList>()).first
        )

        XCTAssertEqual(environment.settings.defaultListID, imported.id)
        XCTAssertEqual(environment.settings.lastQuickCaptureListID, imported.id)
    }

    func testEmptyBackupIsANoOp() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let document = MakeTaskBackupDocument(
            exportedAt: BackupFixtures.date,
            sourceAppVersion: "tests",
            defaultListID: nil,
            lastQuickCaptureListID: nil,
            lists: []
        )

        let result = try environment.coordinator.importBackup(document)

        XCTAssertEqual(result, MakeTaskBackupImportResult(listCount: 0, taskCount: 0, subtaskCount: 0))
        XCTAssertTrue(
            try environment.container.mainContext.fetch(FetchDescriptor<TodoList>()).isEmpty
        )
    }
}
