import SwiftData
import SwiftUI

struct BackupSettingsView: View {
    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]
    @EnvironmentObject private var backup: LocalBackupService

    var body: some View {
        Form {
            Section {
                LabeledContent("Lists", value: "\(lists.count)")
                LabeledContent("Tasks", value: "\(taskCount)")
                LabeledContent("Subtasks", value: "\(subtaskCount)")
                LabeledContent("Backup format", value: "JSON v\(MakeTaskBackupDocument.currentFormatVersion)")
            } header: {
                Text("Local Data")
            }

            Section {
                Button {
                    backup.chooseExportLocation()
                } label: {
                    Label("Export Backup…", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(backup.isWorking)

                Text("Creates a readable, versioned JSON file containing lists, tasks, subtasks, details, ordering, colors, and note window state.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Export")
            }

            Section {
                Button {
                    backup.chooseBackupToImport()
                } label: {
                    Label("Import Backup…", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(backup.isWorking)

                Label(
                    "Import adds the backup as new lists. Existing lists and tasks are never deleted or overwritten.",
                    systemImage: "checkmark.shield"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            } header: {
                Text("Import")
            }

            Section {
                Label("The complete file is validated before any import begins.", systemImage: "checkmark.seal")
                Label("A failed database save rolls back the full import.", systemImage: "arrow.uturn.backward.circle")

                Text("Backups are created and read entirely on this Mac. MakeTask does not require an account or internet connection and does not upload backup files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Safety & Privacy")
            }
        }
        .formStyle(.grouped)
        .alert(item: $backup.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var taskCount: Int {
        lists.reduce(0) { $0 + $1.tasks.count }
    }

    private var subtaskCount: Int {
        lists.reduce(0) { result, list in
            result + list.tasks.reduce(0) { $0 + $1.subtasks.count }
        }
    }
}
