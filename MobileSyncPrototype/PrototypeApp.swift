import SwiftUI

@main
struct PrototypeApp: App {
    @State private var sync = PrototypeSync()

    var body: some Scene {
        WindowGroup("MakeTask") {
            PrototypeHome(sync: sync)
        }
    }
}

struct PrototypeHome: View {
    let sync: PrototypeSync
    @State private var selection: UUID?
    @State private var listDraft: PrototypeList?
    @State private var quickAdd = false
    @State private var showSync = false
    @State private var showBackup = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(sync.lists) { list in
                    NavigationLink(value: list.id) {
                        listRow(list)
                    }
                }
                .onMove(perform: sync.reorderLists)
            }
            .overlay {
                if sync.lists.isEmpty {
                    ContentUnavailableView {
                        Label("No Lists", systemImage: "checklist")
                    } actions: {
                        Button("New List") { listDraft = sync.newList() }
                    }
                }
            }
            .navigationTitle("MakeTask")
            .toolbar {
                ToolbarItemGroup {
                    Button("Quick Add", systemImage: "bolt.fill") { quickAdd = true }
                        .disabled(sync.lists.isEmpty)
                    Button("New List", systemImage: "plus.circle") { listDraft = sync.newList() }
                    #if os(iOS)
                    if sync.lists.count > 1 { EditButton() }
                    #endif
                    Menu {
                        PrototypeHistoryActions(sync: sync)
                        Divider()
                        Button("iCloud Sync", systemImage: "icloud") { showSync = true }
                        Button("Backup", systemImage: "externaldrive") { showBackup = true }
                    } label: {
                        Label("MakeTask Options", systemImage: "ellipsis")
                    }
                }
            }
        } detail: {
            if let selection, let list = sync.list(id: selection) {
                PrototypeListView(sync: sync, list: list)
                    .id(list.id)
            } else {
                ContentUnavailableView("Select a List", systemImage: "square.stack")
            }
        }
        .sheet(item: $listDraft) { list in
            PrototypeListEditor(list: list, title: "New List", save: sync.saveList)
        }
        .sheet(isPresented: $quickAdd) {
            PrototypeQuickAdd(sync: sync, listID: selection ?? sync.lists.first?.id)
        }
        .sheet(isPresented: $showBackup) {
            PrototypeBackupView(sync: sync)
        }
        .sheet(isPresented: $showSync) {
            NavigationStack {
                Form {
                    Text("Pending changes: \(sync.pendingCount)")
                    if let message = sync.message {
                        Text(message).foregroundStyle(.red).textSelection(.enabled)
                    }
                    Button(sync.isConnected ? "Sync Now" : "Connect to iCloud") {
                        Task { await sync.syncNow() }
                    }
                    .disabled(sync.isWorking)
                    if sync.isConnected {
                        Button("Pause Sync", action: sync.pause).disabled(sync.isWorking)
                    }
                    if sync.isWorking { ProgressView() }
                }
                .navigationTitle("iCloud Sync")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showSync = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func listRow(_ list: PrototypeList) -> some View {
        let tasks = sync.tasks(in: list.id)
        let done = tasks.filter(\.isCompleted).count

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(list.color.tint)
                .frame(width: 4, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(list.title).font(.headline)
                if !tasks.isEmpty {
                    ProgressView(value: Double(done), total: Double(tasks.count))
                        .tint(list.color.tint)
                        .accessibilityHidden(true)
                }
            }
            Spacer()
            Text("\(done)/\(tasks.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(done) of \(tasks.count) completed")
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

private struct PrototypeHistoryActions: View {
    let sync: PrototypeSync

    var body: some View {
        Button("Undo", systemImage: "arrow.uturn.backward", action: sync.undo)
            .disabled(!sync.canUndo)
        Button("Redo", systemImage: "arrow.uturn.forward", action: sync.redo)
            .disabled(!sync.canRedo)
    }
}

struct PrototypeListView: View {
    let sync: PrototypeSync
    let list: PrototypeList
    @State private var search = ""
    @State private var newTask = ""
    @State private var taskDraft: PrototypeTask?
    @State private var showListEditor = false
    @State private var confirmDelete = false
    @State private var confirmClearCompleted = false
    @State private var showCompleted = true

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var completed: [PrototypeTask] { sync.tasks(in: list.id).filter(\.isCompleted) }

    var body: some View {
        let tasks = sync.tasks(in: list.id).filter { $0.matches(query) }
        let active = tasks.filter { !$0.isCompleted }
        let done = tasks.filter(\.isCompleted)

        List {
            Section {
                HStack {
                    TextField("Add a task", text: $newTask)
                        .onSubmit(addTask)
                    Button("Add Task", systemImage: "plus", action: addTask)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if tasks.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "No Tasks" : "No Matching Tasks",
                    systemImage: query.isEmpty ? "checkmark.circle" : "magnifyingglass"
                )
            }
            Section {
                ForEach(active) { task in
                    taskRow(task).moveDisabled(!query.isEmpty)
                }
                .onMove { source, destination in
                    guard query.isEmpty else { return }
                    sync.reorderTasks(in: list.id, from: source, to: destination)
                }
                .onDelete { sync.deleteTasks($0.map { active[$0].id }) }
            }
            if !done.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showCompleted) {
                        ForEach(done) { task in
                            taskRow(task)
                        }
                        .onDelete { sync.deleteTasks($0.map { done[$0].id }) }
                    } label: {
                        Text("Completed (\(done.count))")
                    }
                }
            }
        }
        .navigationTitle(list.title)
        .searchable(text: $search, prompt: "Search tasks")
        .toolbar {
            ToolbarItemGroup {
                #if os(iOS)
                if active.count > 1 && query.isEmpty { EditButton() }
                #endif
                Menu {
                    PrototypeHistoryActions(sync: sync)
                    Divider()
                    Button("Edit List", systemImage: "pencil") { showListEditor = true }
                    Button("Clear Completed Tasks", systemImage: "checkmark.circle", role: .destructive) {
                        confirmClearCompleted = true
                    }
                    .disabled(completed.isEmpty)
                    Button("Delete List", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Label("List Options", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showListEditor) {
            PrototypeListEditor(list: list, title: "Edit List", save: sync.saveList)
        }
        .sheet(item: $taskDraft) { task in
            PrototypeTaskEditor(sync: sync, task: task)
        }
        .confirmationDialog("Delete this list and its tasks?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete List", role: .destructive) { sync.deleteList(id: list.id) }
        }
        .confirmationDialog("Clear completed tasks?", isPresented: $confirmClearCompleted, titleVisibility: .visible) {
            Button("Clear Completed Tasks", role: .destructive) { sync.deleteTasks(completed.map(\.id)) }
        }
    }

    private func taskRow(_ task: PrototypeTask) -> some View {
        HStack(spacing: 12) {
            Button {
                sync.toggleTask(id: task.id)
            } label: {
                Image(systemName: task.statusSymbol)
                    .font(.title3)
                    .foregroundStyle(task.isCompleted || task.isInProgress ? list.color.tint : .secondary)
                    .frame(minWidth: 38, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Complete task")
            .accessibilityValue(task.isCompleted ? "Completed" : (task.isInProgress ? "In Progress" : "To Do"))

            Button {
                taskDraft = task
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        taskMetadata(task)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button("Edit Task", systemImage: "pencil") { taskDraft = task }
            if !task.isCompleted {
                Button(
                    task.isInProgress ? "To Do" : "In Progress",
                    systemImage: task.isInProgress ? "circle" : "circle.lefthalf.filled"
                ) {
                    var updated = task
                    updated.isInProgress.toggle()
                    sync.saveTask(updated)
                }
            }
        }
    }

    private func taskMetadata(_ task: PrototypeTask) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { metadataLabels(task) }
            VStack(alignment: .leading, spacing: 4) { metadataLabels(task) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func metadataLabels(_ task: PrototypeTask) -> some View {
        if task.priority != .none {
            Label(task.priority.title, systemImage: task.priority.symbolName)
                .foregroundStyle(task.priority.tint)
        }
        if !task.subtasks.isEmpty {
            Label("\(task.subtasks.filter { $0.completedAt != nil }.count)/\(task.subtasks.count)", systemImage: "checklist")
        }
        if let due = task.dueDate {
            let isLate = !task.isCompleted && due < Calendar.current.startOfDay(for: .now)
            Label {
                Text(due, format: .dateTime.day().month(.abbreviated))
            } icon: {
                Image(systemName: isLate ? "exclamationmark.circle.fill" : "calendar")
            }
            .foregroundStyle(isLate ? Color.red : .secondary)
        }
    }

    private func addTask() {
        sync.addTask(title: newTask, listID: list.id)
        newTask = ""
    }
}
