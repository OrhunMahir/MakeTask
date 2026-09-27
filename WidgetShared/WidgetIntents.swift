import AppIntents
import Foundation

struct WidgetListEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "List")
    static var defaultQuery = WidgetListQuery()
    var id: UUID
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct WidgetListQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetListEntity] {
        let lists = try availableLists()
        // Keep the configured identity even after deletion so WidgetKit cannot
        // resolve a missing selection as the default (first) list.
        return identifiers.map { id in
            lists.first { $0.id == id } ?? WidgetListEntity(id: id, title: "Unavailable list")
        }
    }

    func suggestedEntities() async throws -> [WidgetListEntity] { try availableLists() }

    private func availableLists() throws -> [WidgetListEntity] {
        try WidgetSnapshotStore.shared().read()?.lists.map { WidgetListEntity(id: $0.id, title: $0.title) } ?? []
    }
}

struct TaskWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Task List"
    static var description = IntentDescription("Choose a list to show in your MakeTask widget.")

    @Parameter(title: "List") var list: WidgetListEntity?
    @Parameter(title: "Show completed tasks", default: false) var showCompleted: Bool
}

struct SetWidgetTaskCompletion: AppIntent {
    static var title: LocalizedStringResource = "Set Task Completion"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: "Task") var taskID: String
    @Parameter(title: "Completed") var completed: Bool

    init() {}
    init(taskID: UUID, completed: Bool) {
        self.taskID = taskID.uuidString
        self.completed = completed
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        // App-only foreground-continuable conformance routes execution to the host.
        // Never mutate a second database or report success if host dispatch fails.
        try requireHostApplication()
        #else
        guard let id = UUID(uuidString: taskID),
              let coordinator = WidgetActionDispatcher.coordinator else { throw WidgetDataError.appRequired }
        try coordinator.setTaskCompletionFromWidget(id: id, completed: completed)
        #endif
        return .result()
    }

    #if WIDGET_EXTENSION
    private func requireHostApplication() throws { throw WidgetDataError.appRequired }
    #endif
}

#if !WIDGET_EXTENSION
// Supported from macOS 13.3; keeps task mutations in the app process on macOS 14+.
// No request to enter the foreground is made for a completion action.
extension SetWidgetTaskCompletion: ForegroundContinuableIntent {}
#endif
