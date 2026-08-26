import Foundation
import SwiftData

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
