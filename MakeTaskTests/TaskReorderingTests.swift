import AppKit
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

    func testHoverMovesGapUpAndDownBeforeDropWithoutOscillation() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let fixture = try makeList(title: "Work", taskTitles: ["Alpha", "Beta", "Gamma"], in: environment.container.mainContext)
        let drag = fixture.tasks[2]
        environment.coordinator.beginTaskDrag(drag)
        func hover(_ y: CGFloat) {
            let tasks = fixture.list.orderedTasks
            let frames = Dictionary(uniqueKeysWithValues: tasks.enumerated().map {
                ($0.element.id, CGRect(x: 0, y: CGFloat($0.offset) * 40, width: 300, height: 40))
            })
            environment.coordinator.previewTaskDrop(id: drag.id, to: fixture.list, at: CGPoint(x: 100, y: y), visibleTasks: tasks, rowFrames: frames)
        }
        hover(5)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Gamma", "Alpha", "Beta"])
        for _ in 0..<10 { hover(5) }
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Gamma", "Alpha", "Beta"])
        hover(70)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Gamma", "Beta"])
        for _ in 0..<10 { hover(70) }
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Gamma", "Beta"])
        hover(170)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Beta", "Gamma"])
        environment.coordinator.endTaskDrag()
        XCTAssertFalse(environment.coordinator.canUndo, "Returning to the starting order should not add history")
    }

    func testHoverUsesVariableHeightsAndDoesNotCrossCompletionSections() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let fixture = try makeList(title: "Work", taskTitles: ["Alpha", "Multiline", "Gamma", "Done"], in: environment.container.mainContext)
        fixture.tasks[3].isCompleted = true
        fixture.tasks[2].isInProgress = true
        let frames = Dictionary(uniqueKeysWithValues: zip(fixture.tasks, [
            CGRect(x: 0, y: 0, width: 300, height: 30),
            CGRect(x: 0, y: 30, width: 300, height: 100),
            CGRect(x: 0, y: 130, width: 300, height: 30),
            CGRect(x: 0, y: 190, width: 300, height: 30)
        ]).map { ($0.0.id, $0.1) })
        let drag = fixture.tasks[2]
        environment.coordinator.beginTaskDrag(drag)
        environment.coordinator.previewTaskDrop(id: drag.id, to: fixture.list, at: CGPoint(x: 120, y: 60), visibleTasks: fixture.tasks, rowFrames: frames)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Gamma", "Multiline", "Done"])
        // Drop in blank space below all rows: the active task stays before Completed.
        environment.coordinator.previewTaskDrop(id: drag.id, to: fixture.list, at: CGPoint(x: 120, y: 300), visibleTasks: fixture.tasks, rowFrames: frames)
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Multiline", "Gamma", "Done"])
        XCTAssertTrue(drag.isInProgress)
        XCTAssertFalse(drag.isCompleted)
        environment.coordinator.endTaskDrag()
    }

    func testHoverIntoEmptyListAndCancelRestoresBothListsWithoutHistory() async throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let source = try makeList(title: "Source", taskTitles: ["Alpha", "Beta"], in: environment.container.mainContext)
        let target = try makeList(title: "Empty", taskTitles: [], sortOrder: 1, in: environment.container.mainContext)
        let drag = source.tasks[0]
        environment.coordinator.beginTaskDrag(drag)
        environment.coordinator.previewTaskDrop(id: drag.id, to: target.list, at: CGPoint(x: 100, y: 70), visibleTasks: [], rowFrames: [:])
        XCTAssertEqual(orderedTitles(in: source.list), ["Beta"])
        XCTAssertEqual(orderedTitles(in: target.list), ["Alpha"])
        environment.coordinator.endTaskDrag(committed: false)
        XCTAssertEqual(orderedTitles(in: source.list), ["Alpha", "Beta"])
        XCTAssertTrue(target.list.tasks.isEmpty)
        XCTAssertFalse(environment.coordinator.canUndo)
        XCTAssertNil(environment.coordinator.draggedTaskID)
        let persisted = try ModelContext(environment.container).fetch(FetchDescriptor<TodoTask>())
        XCTAssertEqual(persisted.first(where: { $0.id == drag.id })?.list?.id, source.list.id)
    }

    func testFilteredHoverPreservesTasksOutsideSearchResults() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let fixture = try makeList(title: "Search", taskTitles: ["Alpha", "Hidden", "Gamma"], in: environment.container.mainContext)
        let drag = fixture.tasks[2]
        environment.coordinator.beginTaskDrag(drag)
        environment.coordinator.previewTaskDrop(
            id: drag.id, to: fixture.list, at: CGPoint(x: 50, y: 2),
            visibleTasks: [fixture.tasks[0], drag],
            rowFrames: [fixture.tasks[0].id: CGRect(x: 0, y: 0, width: 300, height: 30), drag.id: CGRect(x: 0, y: 30, width: 300, height: 30)]
        )
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Gamma", "Alpha", "Hidden"])
        environment.coordinator.endTaskDrag()
        XCTAssertTrue(environment.coordinator.undoLastAction())
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Alpha", "Hidden", "Gamma"])
        XCTAssertTrue(environment.coordinator.redoLastAction())
        XCTAssertEqual(orderedTitles(in: fixture.list), ["Gamma", "Alpha", "Hidden"])
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
