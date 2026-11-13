import SwiftUI
import UniformTypeIdentifiers

extension PrototypeSync {
    func makeBackup() -> MakeTaskBackupDocument {
        let exportedAt = Date.now
        return MakeTaskBackupDocument(
            exportedAt: exportedAt,
            sourceAppVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1",
            defaultListID: nil,
            lastQuickCaptureListID: nil,
            lists: lists.map { list in
                MakeTaskBackupDocument.ListRecord(
                    id: list.id, title: list.title, colorRawValue: list.color.rawValue,
                    sortOrder: Double(list.order), createdAt: list.createdAt ?? exportedAt,
                    windowX: nil, windowTop: nil, windowWidth: 320, windowHeight: 360,
                    isCollapsed: false, isCompletedSectionCollapsed: false, isHidden: false,
                    windowModeRawValue: WindowMode.normal.rawValue,
                    tasks: tasks(in: list.id).map { task in
                        MakeTaskBackupDocument.TaskRecord(
                            id: task.id, title: task.title, notes: task.notes, dueDate: task.dueDate,
                            priority: task.priority.rawValue, isCompleted: task.isCompleted,
                            isInProgress: task.isInProgress, completedAt: task.completedAt,
                            createdAt: task.createdAt ?? exportedAt, sortOrder: Double(task.order),
                            subtasks: task.subtasks.enumerated().map { index, subtask in
                                MakeTaskBackupDocument.SubtaskRecord(
                                    id: subtask.id, title: subtask.title, isCompleted: subtask.completedAt != nil,
                                    completedAt: subtask.completedAt, createdAt: subtask.createdAt ?? exportedAt,
                                    sortOrder: Double(index)
                                )
                            }
                        )
                    }
                )
            }
        )
    }

    func importBackup(_ document: MakeTaskBackupDocument) throws -> MakeTaskBackupImportResult {
        try document.validate()
        var names = Set(lists.map { $0.title.lowercased() })
        let nextOrder = (lists.last?.order ?? -1) + 1
        var changes: [(UUID, PrototypeContent)] = []

        let orderedLists = document.lists.sorted {
            ($0.sortOrder, $0.createdAt, $0.id.uuidString) < ($1.sortOrder, $1.createdAt, $1.id.uuidString)
        }
        for (index, item) in orderedLists.enumerated() {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let list = PrototypeList(
                id: UUID(), title: uniqueImportedTitle(title, names: &names),
                color: NoteColor(rawValue: item.colorRawValue) ?? .yellow,
                order: nextOrder + index, createdAt: item.createdAt
            )
            changes.append((list.id, .list(list)))

            let orderedTasks = item.tasks.sorted {
                ($0.sortOrder, $0.createdAt, $0.id.uuidString) < ($1.sortOrder, $1.createdAt, $1.id.uuidString)
            }
            for (taskIndex, entry) in orderedTasks.enumerated() {
                let orderedSubtasks = entry.subtasks.sorted {
                    ($0.sortOrder, $0.createdAt, $0.id.uuidString) < ($1.sortOrder, $1.createdAt, $1.id.uuidString)
                }
                let task = PrototypeTask(
                    id: UUID(), listID: list.id, title: entry.title, order: taskIndex,
                    notes: entry.notes, dueDate: entry.dueDate, priority: TaskPriority(rawValue: entry.priority) ?? .none,
                    isInProgress: entry.isInProgress ?? false,
                    completedAt: entry.isCompleted ? (entry.completedAt ?? entry.createdAt) : nil,
                    subtasks: orderedSubtasks.map { subtask in
                        PrototypeSubtask(
                            id: UUID(), title: subtask.title,
                            completedAt: subtask.isCompleted ? (subtask.completedAt ?? subtask.createdAt) : nil,
                            createdAt: subtask.createdAt
                        )
                    },
                    createdAt: entry.createdAt
                )
                changes.append((task.id, .task(task)))
            }
        }

        guard saveChanges(changes) else { throw PrototypeBackupError.storeWriteFailed }
        return MakeTaskBackupImportResult(
            listCount: document.lists.count, taskCount: document.taskCount, subtaskCount: document.subtaskCount
        )
    }

    private func uniqueImportedTitle(_ title: String, names: inout Set<String>) -> String {
        guard !names.insert(title.lowercased()).inserted else { return title }
        var index = 1
        while true {
            let suffix = index == 1 ? " (Imported)" : " (Imported \(index))"
            let candidate = String(title.prefix(10_000 - suffix.count)) + suffix
            if names.insert(candidate.lowercased()).inserted { return candidate }
            index += 1
        }
    }
}

private enum PrototypeBackupError: LocalizedError {
    case storeWriteFailed

    var errorDescription: String? { "The backup could not be saved to the preview store." }
}

private struct PrototypeBackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(_ data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw MakeTaskBackupError.invalidJSON }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PrototypeBackupView: View {
    @Environment(\.dismiss) private var dismiss
    let sync: PrototypeSync
    @State private var exportFile: PrototypeBackupFile?
    @State private var exporting = false
    @State private var importing = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            Form {
                Button("Export Backup", systemImage: "square.and.arrow.up", action: export)
                    .disabled(sync.lists.isEmpty)
                Button("Import Backup", systemImage: "square.and.arrow.down") { importing = true }
                if let notice { Text(notice).foregroundStyle(.secondary) }
            }
            .navigationTitle("Backup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileExporter(
            isPresented: $exporting, document: exportFile, contentType: .json,
            defaultFilename: "MakeTask Backup"
        ) { result in
            switch result {
            case .success: notice = "Backup exported."
            case .failure(let error): notice = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
                let document = try MakeTaskBackupDocument.read(from: url)
                let imported = try sync.importBackup(document)
                notice = "Added \(imported.listCount) lists, \(imported.taskCount) tasks, and \(imported.subtaskCount) subtasks."
            } catch {
                notice = error.localizedDescription
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func export() {
        do {
            exportFile = PrototypeBackupFile(try sync.makeBackup().encoded())
            exporting = true
        } catch {
            notice = error.localizedDescription
        }
    }
}
