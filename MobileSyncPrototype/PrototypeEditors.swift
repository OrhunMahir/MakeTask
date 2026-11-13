import SwiftUI

struct PrototypeListEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var list: PrototypeList
    let title: String
    let save: (PrototypeList) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("List Name", text: $list.title)
                Picker("Color", selection: $list.color) {
                    ForEach(NoteColor.allCases) { color in
                        Label {
                            Text(color.title)
                        } icon: {
                            Image(systemName: "circle.fill").foregroundStyle(color.tint)
                        }
                        .tag(color)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        list.title = list.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        save(list)
                        dismiss()
                    }
                    .disabled(list.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct PrototypeQuickAdd: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    let sync: PrototypeSync
    @State var listID: UUID?
    @State private var title = ""

    private var canAdd: Bool {
        guard let listID, sync.list(id: listID) != nil else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task Title", text: $title)
                    .focused($isTitleFocused)
                    .onSubmit(add)
                Picker("List", selection: $listID) {
                    ForEach(sync.lists) { list in
                        Text(list.title).tag(Optional(list.id))
                    }
                }
            }
            .navigationTitle("Quick Add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add).disabled(!canAdd)
                }
            }
            .onAppear { isTitleFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        guard canAdd, let listID else { return }
        sync.addTask(title: title, listID: listID)
        dismiss()
    }
}

struct PrototypeTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    let sync: PrototypeSync
    @State var task: PrototypeTask
    @State private var subtaskTitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $task.title)
                    Picker("List", selection: $task.listID) {
                        ForEach(sync.lists) { Text($0.title).tag($0.id) }
                    }
                    Picker("Priority", selection: $task.priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Label(priority.title, systemImage: priority.symbolName)
                                .foregroundStyle(priority.tint)
                                .tag(priority)
                        }
                    }
                    if !task.isCompleted {
                        Picker("Status", selection: $task.isInProgress) {
                            Label("To Do", systemImage: "circle").tag(false)
                            Label("In Progress", systemImage: "circle.lefthalf.filled").tag(true)
                        }
                    }
                    Toggle("Due Date", isOn: Binding(
                        get: { task.dueDate != nil },
                        set: { task.dueDate = $0 ? Calendar.current.startOfDay(for: .now) : nil }
                    ))
                    if task.dueDate != nil {
                        DatePicker("Due", selection: Binding(
                            get: { task.dueDate ?? .now },
                            set: { task.dueDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Add notes", text: $task.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Subtasks") {
                    ForEach($task.subtasks) { $subtask in
                        HStack(spacing: 12) {
                            Button {
                                subtask.completedAt = subtask.completedAt == nil ? .now : nil
                            } label: {
                                Image(systemName: subtask.completedAt == nil ? "circle" : "checkmark.circle.fill")
                                    .frame(minWidth: 34, minHeight: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(subtask.completedAt == nil ? "Complete subtask" : "Mark subtask incomplete")
                            TextField("Subtask Title", text: $subtask.title)
                                .strikethrough(subtask.completedAt != nil)
                        }
                    }
                    .onDelete { task.subtasks.remove(atOffsets: $0) }
                    .onMove { task.subtasks.move(fromOffsets: $0, toOffset: $1) }

                    HStack {
                        TextField("Add a subtask", text: $subtaskTitle)
                            .onSubmit(addSubtask)
                        Button("Add Subtask", systemImage: "plus", action: addSubtask)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .disabled(subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    #if os(iOS)
                    if task.subtasks.count > 1 { EditButton() }
                    #endif
                    Button("Save", action: save)
                        .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addSubtask() {
        let title = subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        task.subtasks.append(PrototypeSubtask(id: UUID(), title: title))
        subtaskTitle = ""
    }

    private func save() {
        addSubtask()
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        sync.saveTask(task)
        dismiss()
    }
}
