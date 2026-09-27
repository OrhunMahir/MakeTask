import Foundation
import SwiftData
import WidgetKit

@MainActor
enum WidgetActionDispatcher {
    static weak var coordinator: WindowCoordinator?
}

@MainActor
enum WidgetBridge {
    static func snapshot(context: ModelContext) throws -> WidgetSnapshot {
        let lists = try context.fetch(FetchDescriptor<TodoList>(sortBy: [SortDescriptor(\TodoList.sortOrder), SortDescriptor(\TodoList.createdAt)]))
        return WidgetSnapshot(lists: lists.map { list in
            WidgetListSnapshot(id: list.id, title: list.title, color: list.colorRawValue,
                               tasks: list.orderedTasks.map {
                WidgetTaskSnapshot(id: $0.id, title: $0.title, isCompleted: $0.isCompleted,
                                   priority: $0.priority, dueDate: $0.dueDate)
            })
        })
    }

    static func publish(context: ModelContext) throws {
        let snapshot = try snapshot(context: context)
        if try WidgetSnapshotStore.shared().write(snapshot) {
            WidgetCenter.shared.reloadTimelines(ofKind: "MakeTaskListWidget")
        }
    }
}
