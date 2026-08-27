import Foundation
import SwiftData

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
