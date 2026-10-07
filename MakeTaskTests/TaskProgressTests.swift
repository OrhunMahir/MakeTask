import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class TaskProgressTests: XCTestCase {
    func testProgressStaysActiveAndSurvivesCompletionUndoDeletionAndBackup() throws {
        let env = try TestEnvironment()
        defer { env.cleanUp() }
        let context = env.container.mainContext
        let list = TodoList(title: "Progress", isHidden: true)
        let task = TodoTask(title: "Apple review", list: list)
        context.insert(list)
        context.insert(task)
        env.coordinator.setInProgress(true, for: task)
        XCTAssertTrue(task.isInProgress)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(list.tasks.filter(\.isCompleted).count, 0)
        XCTAssertTrue(env.coordinator.undoLastAction())
        XCTAssertFalse(task.isInProgress)
        XCTAssertTrue(env.coordinator.redoLastAction())
        XCTAssertTrue(task.isInProgress)
        env.coordinator.toggleTask(task)
        XCTAssertTrue(task.isCompleted)
        XCTAssertTrue(env.coordinator.undoLastAction())
        XCTAssertFalse(task.isCompleted)
        XCTAssertTrue(task.isInProgress)
        env.coordinator.deleteTask(task)
        XCTAssertTrue(env.coordinator.undoLastAction())
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<TodoTask>()).first)
        XCTAssertTrue(restored.isInProgress)
        let backup = try env.coordinator.makeBackupDocument()
        let decoded = try JSONDecoder().decode(MakeTaskBackupDocument.self, from: JSONEncoder().encode(backup))
        XCTAssertEqual(decoded.lists.first?.tasks.first?.isInProgress, true)
        let imported = try TestEnvironment()
        defer { imported.cleanUp() }
        _ = try imported.coordinator.importBackup(decoded)
        XCTAssertTrue(try XCTUnwrap(imported.container.mainContext.fetch(FetchDescriptor<TodoTask>()).first).isInProgress)
    }

    func testOlderBackupWithoutStatusImportsAsToDo() throws {
        let env = try TestEnvironment()
        defer { env.cleanUp() }
        let encoded = try JSONEncoder().encode(BackupFixtures.document())
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("isInProgress"))
        let decoded = try JSONDecoder().decode(MakeTaskBackupDocument.self, from: encoded)
        _ = try env.coordinator.importBackup(decoded)
        let task = try XCTUnwrap(env.container.mainContext.fetch(FetchDescriptor<TodoTask>()).first)
        XCTAssertFalse(task.isInProgress)
        XCTAssertFalse(task.isCompleted)
    }
}
