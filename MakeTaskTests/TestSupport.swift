import Foundation
import SwiftData
@testable import MakeTask

@MainActor
struct TestEnvironment {
    let container: ModelContainer
    let settings: AppSettings
    let coordinator: WindowCoordinator
    let defaults: UserDefaults
    let defaultsSuiteName: String

    init() throws {
        let suiteName = "dev.orhun.MakeTaskTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated test defaults")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let container = try PersistenceController.makeContainer(inMemory: true)
        let settings = AppSettings(defaults: defaults)
        self.container = container
        self.settings = settings
        self.coordinator = WindowCoordinator(
            modelContainer: container,
            settings: settings,
            launchAtLogin: LaunchAtLoginService()
        )
        self.defaults = defaults
        self.defaultsSuiteName = suiteName
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }
}

enum BackupFixtures {
    static let date = Date(timeIntervalSince1970: 1_800_000_000)

    static func document(
        formatVersion: Int = MakeTaskBackupDocument.currentFormatVersion,
        listID: UUID = UUID(),
        taskID: UUID = UUID(),
        subtaskID: UUID = UUID(),
        title: String = "Release",
        isHidden: Bool = true,
        windowWidth: Double = 320,
        windowHeight: Double = 360
    ) -> MakeTaskBackupDocument {
        let subtask = MakeTaskBackupDocument.SubtaskRecord(
            id: subtaskID,
            title: "Run smoke tests",
            isCompleted: true,
            completedAt: date,
            createdAt: date,
            sortOrder: 0
        )
        let task = MakeTaskBackupDocument.TaskRecord(
            id: taskID,
            title: "Publish MakeTask",
            notes: "Keep the release fully local.",
            dueDate: date,
            priority: TaskPriority.high.rawValue,
            isCompleted: false,
            completedAt: nil,
            createdAt: date,
            sortOrder: 0,
            subtasks: [subtask]
        )
        let list = MakeTaskBackupDocument.ListRecord(
            id: listID,
            title: title,
            colorRawValue: NoteColor.teal.rawValue,
            sortOrder: 0,
            createdAt: date,
            windowX: 120,
            windowTop: 840,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            isCollapsed: true,
            isCompletedSectionCollapsed: true,
            isHidden: isHidden,
            windowModeRawValue: WindowMode.normal.rawValue,
            tasks: [task]
        )
        return MakeTaskBackupDocument(
            formatVersion: formatVersion,
            exportedAt: date,
            sourceAppVersion: "tests",
            defaultListID: listID,
            lastQuickCaptureListID: listID,
            lists: [list]
        )
    }
}
