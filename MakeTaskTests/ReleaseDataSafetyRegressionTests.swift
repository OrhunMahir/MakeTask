import Foundation
import SwiftData
import XCTest
@testable import MakeTask

/// Release regressions using in-memory data and temporary files.
@MainActor
final class ReleaseDataSafetyRegressionTests: XCTestCase {
    func testAddTaskUndoRedoPreservesNotesAndDueDate() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let list = TodoList(title: "QA", isHidden: true)
        context.insert(list)
        try context.save()

        environment.coordinator.addTask(title: "QA task", to: list)
        let task = try XCTUnwrap(try context.fetch(FetchDescriptor<TodoTask>()).first)
        let taskID = task.id
        let notes = "This note must survive Undo followed by Redo."
        let dueDate = BackupFixtures.date
        // The production TextEditor writes this binding directly, then schedules saveContext.
        task.notes = notes
        environment.coordinator.setDueDate(dueDate, for: task)
        environment.coordinator.saveContext()

        XCTAssertTrue(environment.coordinator.undoLastAction())
        XCTAssertNil(try fetchTask(taskID, context: context))
        XCTAssertTrue(environment.coordinator.redoLastAction())
        let restored = try XCTUnwrap(try fetchTask(taskID, context: context))
        XCTAssertEqual(restored.notes, notes, "Redo must preserve the details present before Undo removed the task.")
        XCTAssertEqual(restored.dueDate, dueDate, "Redo must preserve the due date present before Undo removed the task.")
    }

    func testDeleteUndoDetailEditRedoUndoPreservesLatestDetails() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let list = TodoList(title: "QA", isHidden: true)
        let task = TodoTask(title: "Existing QA task", notes: "Original note", list: list)
        let taskID = task.id
        context.insert(list)
        context.insert(task)
        try context.save()

        environment.coordinator.deleteTask(task)
        XCTAssertTrue(environment.coordinator.undoLastAction())
        let restored = try XCTUnwrap(try fetchTask(taskID, context: context))
        let updatedNotes = "Details edited after restoring the task."
        let updatedDueDate = BackupFixtures.date
        restored.notes = updatedNotes
        environment.coordinator.setDueDate(updatedDueDate, for: restored)
        environment.coordinator.saveContext()

        if !environment.coordinator.canRedo {
            // Invalidating obsolete deletion redo after a new user edit is also safe.
            XCTAssertEqual(restored.notes, updatedNotes)
            XCTAssertEqual(restored.dueDate, updatedDueDate)
            return
        }
        XCTAssertTrue(environment.coordinator.redoLastAction())
        XCTAssertNil(try fetchTask(taskID, context: context))
        XCTAssertTrue(environment.coordinator.undoLastAction())
        let latest = try XCTUnwrap(try fetchTask(taskID, context: context))
        XCTAssertEqual(latest.notes, updatedNotes, "Undo must recover the details immediately preceding the repeated deletion.")
        XCTAssertEqual(latest.dueDate, updatedDueDate, "Undo must recover the latest due date.")
    }

    func testSuccessfulLargeBackupEncodingMustRemainImportable() throws {
        let fixture = BackupFixtures.document()
        let record = fixture.lists[0]
        let notes = String(repeating: "a", count: 1_000_000)
        let tasks = (0..<27).map { index in
            MakeTaskBackupDocument.TaskRecord(
                id: UUID(), title: "Task \(index)", notes: notes,
                dueDate: nil, priority: 0, isCompleted: false,
                completedAt: nil, createdAt: BackupFixtures.date,
                sortOrder: Double(index), subtasks: []
            )
        }
        let largeList = MakeTaskBackupDocument.ListRecord(
            id: record.id, title: record.title, colorRawValue: record.colorRawValue,
            sortOrder: record.sortOrder, createdAt: record.createdAt,
            windowX: record.windowX, windowTop: record.windowTop,
            windowWidth: record.windowWidth, windowHeight: record.windowHeight,
            isCollapsed: record.isCollapsed,
            isCompletedSectionCollapsed: record.isCompletedSectionCollapsed,
            isHidden: record.isHidden, windowModeRawValue: record.windowModeRawValue,
            tasks: tasks
        )
        let document = MakeTaskBackupDocument(
            exportedAt: fixture.exportedAt, sourceAppVersion: fixture.sourceAppVersion,
            defaultListID: largeList.id, lastQuickCaptureListID: largeList.id,
            lists: [largeList]
        )
        try document.validate()

        let encoded: Data
        do {
            encoded = try LocalBackupService.encode(document)
        } catch MakeTaskBackupError.fileTooLarge {
            // Explicit refusal during export is acceptable; false success is not.
            return
        } catch {
            XCTFail("Unexpected encoding failure for structurally valid data: \(error)")
            return
        }
        XCTAssertGreaterThan(encoded.count, MakeTaskBackupDocument.maximumFileSize)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MakeTask-large-roundtrip-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try encoded.write(to: url, options: .atomic)
        do {
            let decoded = try LocalBackupService.decode(contentsOf: url)
            XCTAssertEqual(decoded, document)
        } catch {
            XCTFail("Encoding succeeded for \(encoded.count) bytes but the app rejects its own backup: \(error)")
        }
    }

    func testRepeatedListDeletionPreservesLatestDetailsAndWindowState() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let list = TodoList(title: "QA list", isHidden: true)
        let task = TodoTask(title: "Retained task", notes: "Original", list: list)
        let listID = list.id
        let taskID = task.id
        context.insert(list)
        context.insert(task)
        try context.save()

        environment.coordinator.deleteList(list)
        XCTAssertTrue(environment.coordinator.undoLastAction())
        let restoredTask = try XCTUnwrap(try fetchTask(taskID, context: context))
        let restoredList = try XCTUnwrap(restoredTask.list)
        restoredTask.notes = "Latest note"
        environment.coordinator.setDueDate(BackupFixtures.date, for: restoredTask)
        restoredList.isCollapsed = true
        restoredList.windowWidth = 420
        environment.coordinator.saveContext()
        XCTAssertTrue(environment.coordinator.redoLastAction())
        XCTAssertNil(try fetchTask(taskID, context: context))
        XCTAssertTrue(environment.coordinator.undoLastAction())

        let latest = try XCTUnwrap(try fetchTask(taskID, context: context))
        XCTAssertEqual(latest.notes, "Latest note")
        XCTAssertEqual(latest.dueDate, BackupFixtures.date)
        XCTAssertEqual(latest.list?.id, listID)
        XCTAssertEqual(latest.list?.windowWidth, 420)
        XCTAssertEqual(latest.list?.isCollapsed, true)
    }

    func testRepeatedClearCompletedPreservesEditedDetailsAndUnrelatedTasks() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let list = TodoList(title: "QA", isHidden: true)
        let completed = TodoTask(title: "Completed", isCompleted: true, list: list)
        let pending = TodoTask(title: "Keep me", list: list)
        let taskID = completed.id
        let pendingID = pending.id
        context.insert(list)
        context.insert(completed)
        context.insert(pending)
        try context.save()

        environment.coordinator.clearCompletedTasks(in: list)
        XCTAssertTrue(environment.coordinator.undoLastAction())
        let restored = try XCTUnwrap(try fetchTask(taskID, context: context))
        restored.notes = "New completed-task details"
        environment.coordinator.setDueDate(BackupFixtures.date, for: restored)
        XCTAssertTrue(environment.coordinator.redoLastAction())
        XCTAssertNil(try fetchTask(taskID, context: context))
        XCTAssertNotNil(try fetchTask(pendingID, context: context))
        XCTAssertTrue(environment.coordinator.undoLastAction())

        let latest = try XCTUnwrap(try fetchTask(taskID, context: context))
        XCTAssertEqual(latest.notes, "New completed-task details")
        XCTAssertEqual(latest.dueDate, BackupFixtures.date)
        XCTAssertTrue(latest.isCompleted)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodoTask>()), 2)
    }

    func testOversizedExportLeavesExistingBackupUntouchedAndReportsError() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let list = TodoList(title: "QA large backup", isHidden: true)
        context.insert(list)
        let notes = String(repeating: "a", count: 1_000_000)
        for index in 0..<27 {
            context.insert(TodoTask(title: "Task \(index)", notes: notes, list: list))
        }
        try context.save()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MakeTask-protected-backup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let existing = try LocalBackupService.encode(BackupFixtures.document())
        try existing.write(to: url)

        let service = LocalBackupService(coordinator: environment.coordinator)
        service.exportBackup(to: url)

        XCTAssertEqual(service.notice?.kind, .error)
        XCTAssertFalse(service.isWorking)
        XCTAssertEqual(try Data(contentsOf: url), existing)
    }

    private func fetchTask(_ id: UUID, context: ModelContext) throws -> TodoTask? {
        try context.fetch(FetchDescriptor<TodoTask>(predicate: #Predicate { $0.id == id })).first
    }
}
