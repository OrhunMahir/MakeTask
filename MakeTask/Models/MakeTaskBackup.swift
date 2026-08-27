import Foundation

struct MakeTaskBackupDocument: Codable, Equatable {
    static let currentFormatVersion = 1
    static let maximumFileSize = 25 * 1_024 * 1_024

    let formatVersion: Int
    let exportedAt: Date
    let sourceAppVersion: String
    let defaultListID: UUID?
    let lastQuickCaptureListID: UUID?
    let lists: [ListRecord]

    init(
        formatVersion: Int = Self.currentFormatVersion,
        exportedAt: Date = .now,
        sourceAppVersion: String,
        defaultListID: UUID?,
        lastQuickCaptureListID: UUID?,
        lists: [ListRecord]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.sourceAppVersion = sourceAppVersion
        self.defaultListID = defaultListID
        self.lastQuickCaptureListID = lastQuickCaptureListID
        self.lists = lists
    }

    init(
        lists: [TodoList],
        sourceAppVersion: String,
        defaultListID: UUID?,
        lastQuickCaptureListID: UUID?
    ) {
        self.init(
            sourceAppVersion: sourceAppVersion,
            defaultListID: defaultListID,
            lastQuickCaptureListID: lastQuickCaptureListID,
            lists: lists.map(ListRecord.init)
        )
    }

    var taskCount: Int {
        lists.reduce(0) { $0 + $1.tasks.count }
    }

    var subtaskCount: Int {
        lists.reduce(0) { result, list in
            result + list.tasks.reduce(0) { $0 + $1.subtasks.count }
        }
    }

    func validate() throws {
        guard formatVersion == Self.currentFormatVersion else {
            if formatVersion > Self.currentFormatVersion {
                throw MakeTaskBackupError.newerFormat(formatVersion)
            }
            throw MakeTaskBackupError.unsupportedFormat(formatVersion)
        }
        guard lists.count <= 1_000 else {
            throw MakeTaskBackupError.tooManyItems("lists", maximum: 1_000)
        }
        guard taskCount <= 100_000 else {
            throw MakeTaskBackupError.tooManyItems("tasks", maximum: 100_000)
        }
        guard subtaskCount <= 500_000 else {
            throw MakeTaskBackupError.tooManyItems("subtasks", maximum: 500_000)
        }

        var listIDs = Set<UUID>()
        var taskIDs = Set<UUID>()
        var subtaskIDs = Set<UUID>()

        for list in lists {
            try Self.validateTitle(list.title, item: "list")
            guard listIDs.insert(list.id).inserted else {
                throw MakeTaskBackupError.duplicateIdentifier
            }
            guard list.windowWidth.isFinite, list.windowHeight.isFinite,
                  list.sortOrder.isFinite,
                  list.windowX?.isFinite ?? true,
                  list.windowTop?.isFinite ?? true else {
                throw MakeTaskBackupError.invalidWindowData
            }

            for task in list.tasks {
                try Self.validateTitle(task.title, item: "task")
                guard task.notes.count <= 1_000_000 else {
                    throw MakeTaskBackupError.textTooLong("task notes")
                }
                guard task.sortOrder.isFinite else {
                    throw MakeTaskBackupError.invalidOrdering
                }
                guard taskIDs.insert(task.id).inserted else {
                    throw MakeTaskBackupError.duplicateIdentifier
                }

                for subtask in task.subtasks {
                    try Self.validateTitle(subtask.title, item: "subtask")
                    guard subtask.sortOrder.isFinite else {
                        throw MakeTaskBackupError.invalidOrdering
                    }
                    guard subtaskIDs.insert(subtask.id).inserted else {
                        throw MakeTaskBackupError.duplicateIdentifier
                    }
                }
            }
        }

        if let defaultListID, !listIDs.contains(defaultListID) {
            throw MakeTaskBackupError.invalidDefaultList
        }
        if let lastQuickCaptureListID, !listIDs.contains(lastQuickCaptureListID) {
            throw MakeTaskBackupError.invalidDefaultList
        }
    }

    private static func validateTitle(_ title: String, item: String) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MakeTaskBackupError.emptyTitle(item)
        }
        guard title.count <= 10_000 else {
            throw MakeTaskBackupError.textTooLong("\(item) title")
        }
    }

    struct ListRecord: Codable, Equatable {
        let id: UUID
        let title: String
        let colorRawValue: String
        let sortOrder: Double
        let createdAt: Date
        let windowX: Double?
        let windowTop: Double?
        let windowWidth: Double
        let windowHeight: Double
        let isCollapsed: Bool
        let isCompletedSectionCollapsed: Bool
        let isHidden: Bool
        let windowModeRawValue: String
        let tasks: [TaskRecord]

        init(list: TodoList) {
            id = list.id
            title = list.title
            colorRawValue = list.colorRawValue
            sortOrder = list.sortOrder
            createdAt = list.createdAt
            windowX = list.windowX
            windowTop = list.windowTop
            windowWidth = list.windowWidth
            windowHeight = list.windowHeight
            isCollapsed = list.isCollapsed
            isCompletedSectionCollapsed = list.isCompletedSectionCollapsed
            isHidden = list.isHidden
            windowModeRawValue = list.windowModeRawValue
            tasks = list.orderedTasks.map(TaskRecord.init)
        }

        init(
            id: UUID,
            title: String,
            colorRawValue: String,
            sortOrder: Double,
            createdAt: Date,
            windowX: Double?,
            windowTop: Double?,
            windowWidth: Double,
            windowHeight: Double,
            isCollapsed: Bool,
            isCompletedSectionCollapsed: Bool,
            isHidden: Bool,
            windowModeRawValue: String,
            tasks: [TaskRecord]
        ) {
            self.id = id
            self.title = title
            self.colorRawValue = colorRawValue
            self.sortOrder = sortOrder
            self.createdAt = createdAt
            self.windowX = windowX
            self.windowTop = windowTop
            self.windowWidth = windowWidth
            self.windowHeight = windowHeight
            self.isCollapsed = isCollapsed
            self.isCompletedSectionCollapsed = isCompletedSectionCollapsed
            self.isHidden = isHidden
            self.windowModeRawValue = windowModeRawValue
            self.tasks = tasks
        }
    }

    struct TaskRecord: Codable, Equatable {
        let id: UUID
        let title: String
        let notes: String
        let dueDate: Date?
        let priority: Int
        let isCompleted: Bool
        let completedAt: Date?
        let createdAt: Date
        let sortOrder: Double
        let subtasks: [SubtaskRecord]

        init(task: TodoTask) {
            id = task.id
            title = task.title
            notes = task.notes
            dueDate = task.dueDate
            priority = task.priority
            isCompleted = task.isCompleted
            completedAt = task.completedAt
            createdAt = task.createdAt
            sortOrder = task.sortOrder
            subtasks = task.orderedSubtasks.map(SubtaskRecord.init)
        }

        init(
            id: UUID,
            title: String,
            notes: String,
            dueDate: Date?,
            priority: Int,
            isCompleted: Bool,
            completedAt: Date?,
            createdAt: Date,
            sortOrder: Double,
            subtasks: [SubtaskRecord]
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
            self.subtasks = subtasks
        }
    }

    struct SubtaskRecord: Codable, Equatable {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let completedAt: Date?
        let createdAt: Date
        let sortOrder: Double

        init(subtask: TodoSubtask) {
            id = subtask.id
            title = subtask.title
            isCompleted = subtask.isCompleted
            completedAt = subtask.completedAt
            createdAt = subtask.createdAt
            sortOrder = subtask.sortOrder
        }

        init(
            id: UUID,
            title: String,
            isCompleted: Bool,
            completedAt: Date?,
            createdAt: Date,
            sortOrder: Double
        ) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.completedAt = completedAt
            self.createdAt = createdAt
            self.sortOrder = sortOrder
        }
    }
}

struct MakeTaskBackupImportResult: Equatable {
    let listCount: Int
    let taskCount: Int
    let subtaskCount: Int
}

enum MakeTaskBackupError: LocalizedError, Equatable {
    case fileTooLarge
    case newerFormat(Int)
    case unsupportedFormat(Int)
    case tooManyItems(String, maximum: Int)
    case duplicateIdentifier
    case emptyTitle(String)
    case textTooLong(String)
    case invalidWindowData
    case invalidOrdering
    case invalidDefaultList
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            "This backup is larger than MakeTask's 25 MB safety limit."
        case let .newerFormat(version):
            "This backup uses format version \(version). Update MakeTask before importing it."
        case let .unsupportedFormat(version):
            "Backup format version \(version) is not supported."
        case let .tooManyItems(item, maximum):
            "This backup contains too many \(item). The safety limit is \(maximum)."
        case .duplicateIdentifier:
            "This backup contains duplicate item identifiers."
        case let .emptyTitle(item):
            "This backup contains a \(item) with an empty title."
        case let .textTooLong(field):
            "This backup contains an unusually long \(field)."
        case .invalidWindowData:
            "This backup contains invalid window position or size data."
        case .invalidOrdering:
            "This backup contains invalid task ordering data."
        case .invalidDefaultList:
            "This backup refers to a default list that does not exist."
        case .invalidJSON:
            "This file is not a valid MakeTask backup."
        }
    }
}
