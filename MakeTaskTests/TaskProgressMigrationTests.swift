import SwiftData
import XCTest
@testable import MakeTask

// Frozen 1.1.1 models create a real pre-status SQLite store, never the user's store.
private enum BeforeProgress {

@Model
final class TodoList {
    @Attribute(.unique) var id: UUID
    var title: String
    var colorRawValue: String
    var sortOrder: Double
    var createdAt: Date

    // windowTop is used instead of origin.y so a roll-up keeps its header anchored.
    var windowX: Double?
    var windowTop: Double?
    var windowWidth: Double
    var windowHeight: Double
    var isCollapsed: Bool
    var isCompletedSectionCollapsed: Bool = false
    var isHidden: Bool
    var windowModeRawValue: String

    @Relationship(deleteRule: .cascade, inverse: \TodoTask.list)
    var tasks: [TodoTask]

    init(
        id: UUID = UUID(),
        title: String,
        color: NoteColor = .yellow,
        sortOrder: Double = 0,
        createdAt: Date = .now,
        windowX: Double? = nil,
        windowTop: Double? = nil,
        windowWidth: Double = 320,
        windowHeight: Double = 360,
        isCollapsed: Bool = false,
        isCompletedSectionCollapsed: Bool = false,
        isHidden: Bool = false,
        windowMode: WindowMode = .normal,
        tasks: [TodoTask] = []
    ) {
        self.id = id
        self.title = title
        self.colorRawValue = color.rawValue
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.windowX = windowX
        self.windowTop = windowTop
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.isCollapsed = isCollapsed
        self.isCompletedSectionCollapsed = isCompletedSectionCollapsed
        self.isHidden = isHidden
        self.windowModeRawValue = windowMode.rawValue
        self.tasks = tasks
    }

    var noteColor: NoteColor {
        get { NoteColor(rawValue: colorRawValue) ?? .yellow }
        set { colorRawValue = newValue.rawValue }
    }

    var windowMode: WindowMode {
        get { WindowMode(rawValue: windowModeRawValue) ?? .normal }
        set { windowModeRawValue = newValue.rawValue }
    }

    var orderedTasks: [TodoTask] {
        tasks.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }
}

@Model
final class TodoTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var dueDate: Date?
    var priority: Int
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var sortOrder: Double
    var list: TodoList?

    @Relationship(deleteRule: .cascade, inverse: \TodoSubtask.task)
    var subtasks: [TodoSubtask]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        priority: Int = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        sortOrder: Double = 0,
        list: TodoList? = nil,
        subtasks: [TodoSubtask] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.list = list
        self.subtasks = subtasks
    }

    var priorityLevel: TaskPriority {
        get { TaskPriority(rawValue: priority) ?? .none }
        set { priority = newValue.rawValue }
    }

    var orderedSubtasks: [TodoSubtask] {
        subtasks.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }
}

@Model
final class TodoSubtask {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var sortOrder: Double
    var task: TodoTask?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        sortOrder: Double = 0,
        task: TodoTask? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.task = task
    }
}
}

@MainActor
final class TaskProgressMigrationTests: XCTestCase {
    func testExistingStoreMigratesAndProgressPersistsAfterReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Migration.store")
        try autoreleasepool {
            let schema = Schema([BeforeProgress.TodoList.self, BeforeProgress.TodoTask.self, BeforeProgress.TodoSubtask.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            let list = BeforeProgress.TodoList(title: "Existing list")
            let task = BeforeProgress.TodoTask(title: "Existing task", notes: "Keep me", list: list)
            let done = BeforeProgress.TodoTask(title: "Done", isCompleted: true, list: list)
            let child = BeforeProgress.TodoSubtask(title: "Existing subtask", task: task)
            context.insert(list)
            context.insert(task)
            context.insert(done)
            context.insert(child)
            try context.save()
        }
        let schema = Schema([TodoList.self, TodoTask.self, TodoSubtask.self])
        try autoreleasepool {
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let tasks = try container.mainContext.fetch(FetchDescriptor<TodoTask>())
            XCTAssertEqual(tasks.count, 2)
            XCTAssertTrue(tasks.allSatisfy { !$0.isInProgress })
            XCTAssertTrue(try XCTUnwrap(tasks.first { $0.title == "Done" }).isCompleted)
            let task = try XCTUnwrap(tasks.first { $0.title == "Existing task" })
            XCTAssertEqual(task.notes, "Keep me")
            XCTAssertEqual(task.list?.title, "Existing list")
            XCTAssertEqual(task.subtasks.first?.title, "Existing subtask")
            task.isInProgress = true
            try container.mainContext.save()
        }
        let reopened = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let task = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<TodoTask>()).first { $0.title == "Existing task" })
        XCTAssertTrue(task.isInProgress)
        XCTAssertFalse(task.isCompleted)
    }
}
