import Foundation
import SwiftData

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
