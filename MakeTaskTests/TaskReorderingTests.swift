import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class TaskReorderingTests: XCTestCase {
    func testMovesTaskToFirstPositionWithinList() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let fixture = try makeList(
            title: "Work",
            taskTitles: ["Alpha", "Beta", "Gamma"],
            in: environment.container.mainContext
        )

        let moved = environment.coordinator.moveTask(
            id: fixture.tasks[2].id,
            to: fixture.list,
            relativeTo: fixture.tasks[0],
            edge: .top
        )

        XCTAssertTrue(moved)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Gamma", "Alpha", "Beta"])
        assertContiguousSortOrders(in: fixture.list)
    }

    func testMovesTaskToLastPositionWithinList() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let fixture = try makeList(
            title: "Work",
            taskTitles: ["Alpha", "Beta", "Gamma"],
            in: environment.container.mainContext
        )

        let moved = environment.coordinator.moveTask(
            id: fixture.tasks[0].id,
            to: fixture.list,
            relativeTo: fixture.tasks[2],
            edge: .bottom
        )

        XCTAssertTrue(moved)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Beta", "Gamma", "Alpha"])
        assertContiguousSortOrders(in: fixture.list)
    }

    func testDroppingAtCurrentPositionIsANoOp() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let fixture = try makeList(
            title: "Work",
            taskTitles: ["Alpha", "Beta", "Gamma"],
            in: environment.container.mainContext
        )

        let moved = environment.coordinator.moveTask(
            id: fixture.tasks[1].id,
            to: fixture.list,
            relativeTo: fixture.tasks[0],
            edge: .bottom
        )

        XCTAssertFalse(moved)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Beta", "Gamma"])
        assertContiguousSortOrders(in: fixture.list)
    }

    func testMovesTaskBetweenListsAtRequestedEdge() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let source = try makeList(
            title: "Source",
            taskTitles: ["Alpha", "Beta", "Gamma"],
            in: context
        )
        let target = try makeList(
            title: "Target",
            taskTitles: ["Delta", "Epsilon"],
            sortOrder: 1,
            in: context
        )

        let movedTask = source.tasks[1]
        let moved = environment.coordinator.moveTask(
            id: movedTask.id,
            to: target.list,
            relativeTo: target.tasks[1],
            edge: .top
        )

        XCTAssertTrue(moved)
        XCTAssertEqual(movedTask.list?.id, target.list.id)
        XCTAssertEqual(orderedTitles(in: source.list), ["Alpha", "Gamma"])
        XCTAssertEqual(orderedTitles(in: target.list), ["Delta", "Beta", "Epsilon"])
        assertContiguousSortOrders(in: source.list)
        assertContiguousSortOrders(in: target.list)
    }

    func testMovesTaskToEmptyList() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let source = try makeList(
            title: "Source",
            taskTitles: ["Only task"],
            in: context
        )
        let target = try makeList(
            title: "Target",
            taskTitles: [],
            sortOrder: 1,
            in: context
        )

        let moved = environment.coordinator.moveTask(
            id: source.tasks[0].id,
            to: target.list
        )

        XCTAssertTrue(moved)
        XCTAssertTrue(source.list.orderedTasks.isEmpty)
        XCTAssertEqual(orderedTitles(in: target.list), ["Only task"])
        XCTAssertEqual(target.list.orderedTasks.first?.sortOrder, 0)
    }

    func testMovingTaskPreservesCompletionState() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let source = try makeList(
            title: "Source",
            taskTitles: ["Completed task"],
            in: context
        )
        let target = try makeList(
            title: "Target",
            taskTitles: ["Active task"],
            sortOrder: 1,
            in: context
        )
        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        source.tasks[0].isCompleted = true
        source.tasks[0].completedAt = completedAt
        try context.save()

        XCTAssertTrue(environment.coordinator.moveTask(id: source.tasks[0].id, to: target.list))

        XCTAssertTrue(source.tasks[0].isCompleted)
        XCTAssertEqual(source.tasks[0].completedAt, completedAt)
        XCTAssertEqual(source.tasks[0].list?.id, target.list.id)
    }

    func testDragLifecycleClearsVisualStateAndSupportsUndoRedo() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let fixture = try makeList(
            title: "Work",
            taskTitles: ["Alpha", "Beta", "Gamma"],
            in: environment.container.mainContext
        )
        let draggedTask = fixture.tasks[2]
        let targetTask = fixture.tasks[0]

        environment.coordinator.beginTaskDrag(draggedTask)
        environment.coordinator.updateTaskDropTarget(targetTask: targetTask, edge: .top)
        XCTAssertTrue(environment.coordinator.moveTask(
            id: draggedTask.id,
            to: fixture.list,
            relativeTo: targetTask,
            edge: .top,
            persistImmediately: false
        ))

        XCTAssertEqual(environment.coordinator.draggedTaskID, draggedTask.id)
        XCTAssertEqual(environment.coordinator.taskDropTargetID, targetTask.id)
        XCTAssertEqual(environment.coordinator.taskDropEdge, .top)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Gamma", "Alpha", "Beta"])

        environment.coordinator.endTaskDrag()

        XCTAssertNil(environment.coordinator.draggedTaskID)
        XCTAssertNil(environment.coordinator.taskDropTargetID)
        XCTAssertTrue(environment.coordinator.canUndo)
        XCTAssertTrue(environment.coordinator.undoLastAction())
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Beta", "Gamma"])
        XCTAssertTrue(environment.coordinator.canRedo)
        XCTAssertTrue(environment.coordinator.redoLastAction())
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Gamma", "Alpha", "Beta"])
    }

    func testDragMovePersistsAfterDrop() async throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let context = environment.container.mainContext
        let source = try makeList(
            title: "Source",
            taskTitles: ["Alpha", "Beta"],
            in: context
        )
        let target = try makeList(
            title: "Target",
            taskTitles: ["Gamma"],
            sortOrder: 1,
            in: context
        )

        environment.coordinator.beginTaskDrag(source.tasks[0])
        XCTAssertTrue(environment.coordinator.moveTask(
            id: source.tasks[0].id,
            to: target.list,
            relativeTo: target.tasks[0],
            edge: .bottom,
            persistImmediately: false
        ))
        environment.coordinator.endTaskDrag()

        try await Task.sleep(for: .milliseconds(250))

        let verificationContext = ModelContext(environment.container)
        let persistedTasks = try verificationContext.fetch(
            FetchDescriptor<TodoTask>(sortBy: [SortDescriptor(\TodoTask.sortOrder)])
        )
        let sourceTitles = persistedTasks
            .filter { $0.list?.id == source.list.id }
            .map(\.title)
        let targetTitles = persistedTasks
            .filter { $0.list?.id == target.list.id }
            .map(\.title)

        XCTAssertEqual(sourceTitles, ["Beta"])
        XCTAssertEqual(targetTitles, ["Gamma", "Alpha"])
    }

    private func makeList(
        title: String,
        taskTitles: [String],
        sortOrder: Double = 0,
        in context: ModelContext
    ) throws -> (list: TodoList, tasks: [TodoTask]) {
        let list = TodoList(title: title, sortOrder: sortOrder)
        context.insert(list)
        let tasks = taskTitles.enumerated().map { index, title in
            TodoTask(
                title: title,
                createdAt: Date(timeIntervalSince1970: Double(index + 1)),
                sortOrder: Double(index),
                list: list
            )
        }
        tasks.forEach(context.insert)
        try context.save()
        return (list, tasks)
    }

    private func orderedTitles(in list: TodoList) -> [String] {
        list.orderedTasks.map(\.title)
    }

    private func assertContiguousSortOrders(
        in list: TodoList,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            list.orderedTasks.map(\.sortOrder),
            list.orderedTasks.indices.map(Double.init),
            file: file,
            line: line
        )
    }
}
