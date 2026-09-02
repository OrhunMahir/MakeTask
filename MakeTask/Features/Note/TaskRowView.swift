import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TaskRowView: View {
    @Bindable var task: TodoTask
    let list: TodoList
    @Binding var selectedTaskID: UUID?
    @Binding var editingTaskID: UUID?
    @Binding var expandedTaskID: UUID?

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var titleDraft = ""
    @State private var rowSize: CGSize = .zero
    @FocusState private var isTitleFocused: Bool

    private var isSelected: Bool {
        selectedTaskID == task.id
    }

    private var isEditing: Bool {
        editingTaskID == task.id
    }

    private var isDragging: Bool {
        coordinator.draggedTaskID == task.id
    }

    private var isExpanded: Bool {
        expandedTaskID == task.id
    }

    private var isDropTarget: Bool {
        coordinator.taskDropTargetID == task.id && !isDragging
    }

    private var isOverdue: Bool {
        guard !task.isCompleted, let dueDate = task.dueDate else { return false }
        return dueDate < coordinator.dueDateReferenceDate
    }

    private var completedSubtaskCount: Int {
        task.subtasks.filter(\.isCompleted).count
    }

    private var showsMetadata: Bool {
        isOverdue || task.priorityLevel != .none || !task.subtasks.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            taskHeader

            if isExpanded && !isEditing {
                TaskDetailView(task: task)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(isDragging ? 0 : 1)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(list.noteColor.tint.opacity(isDragging ? 0.08 : (isSelected ? 0.09 : 0)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    list.noteColor.tint.opacity(isDragging ? 0.62 : (isSelected ? 0.62 : 0)),
                    lineWidth: isDragging ? 1.5 : (isSelected ? 1 : 0)
                )
        }
        .overlay(alignment: coordinator.taskDropEdge == .top ? .top : .bottom) {
            if isDropTarget {
                Capsule()
                    .fill(list.noteColor.tint)
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .shadow(color: list.noteColor.tint.opacity(0.35), radius: 3)
                    .transition(.opacity)
            }
        }
        .zIndex(isDragging ? 2 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isExpanded)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit Task") {
                beginEditing()
            }
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                completeTask()
            }
            Menu("Priority") {
                ForEach(TaskPriority.allCases) { priority in
                    Button {
                        coordinator.setPriority(priority, for: task)
                    } label: {
                        Label(
                            priority.title,
                            systemImage: priority == task.priorityLevel
                                ? "checkmark"
                                : priority.symbolName
                        )
                    }
                }
            }
            Divider()
            Button("Delete Task", role: .destructive) {
                coordinator.deleteTask(task)
            }
        }
        .onDrop(
            of: [UTType.text],
            delegate: TaskRowDropDelegate(
                targetTask: task,
                targetList: list,
                coordinator: coordinator,
                targetHeight: rowSize.height,
                reduceMotion: reduceMotion
            )
        )
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TaskRowFramePreferenceKey.self,
                    value: [
                        task.id: proxy.frame(
                            in: .named("task-scroll-\(list.id.uuidString)")
                        )
                    ]
                )
            }
        }
        .onPreferenceChange(TaskRowFramePreferenceKey.self) { frames in
            if let frame = frames[task.id] {
                rowSize = frame.size
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                titleDraft = task.title
                DispatchQueue.main.async {
                    isTitleFocused = true
                    DispatchQueue.main.async {
                        (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
                    }
                }
            }
        }
        .onChange(of: isTitleFocused) { _, focused in
            if !focused && isEditing {
                commitEditing()
            }
        }
    }

    private var taskHeader: some View {
        HStack(alignment: .center, spacing: 9) {
            Button {
                selectedTaskID = task.id
                completeTask()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(task.isCompleted ? list.noteColor.tint : .secondary)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Mark incomplete" : "Mark complete")
            .accessibilityIdentifier("task.checkbox.\(task.id.uuidString)")
            .accessibilityLabel(
                task.isCompleted
                    ? "Mark \(task.title) incomplete"
                    : "Complete \(task.title)"
            )

            if isEditing {
                TextField("Task title", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(settings.font(size: 13.5))
                    .accessibilityIdentifier("task.title-field")
                    .focused($isTitleFocused)
                    .onSubmit(commitEditing)
                    .onExitCommand(perform: cancelEditing)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(settings.font(size: 13.5))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .accessibilityIdentifier("task.title.\(task.id.uuidString)")

                    if showsMetadata {
                        HStack(spacing: 8) {
                            if task.priorityLevel != .none {
                                Label(task.priorityLevel.title, systemImage: task.priorityLevel.symbolName)
                                    .foregroundStyle(
                                        task.priorityLevel.tint.opacity(task.isCompleted ? 0.58 : 1)
                                    )
                                    .help("\(task.priorityLevel.title) priority")
                            }

                            if !task.subtasks.isEmpty {
                                Label(
                                    "\(completedSubtaskCount)/\(task.subtasks.count)",
                                    systemImage: "checklist"
                                )
                                .foregroundStyle(.secondary)
                                .help("Completed subtasks")
                            }

                            if isOverdue {
                                Label("Missed due date", systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .transition(.opacity)
                            }
                        }
                        .font(settings.font(size: 9.5, weight: .semibold))
                        .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .overlay {
                    TaskDragSourceView(
                        taskID: task.id,
                        title: task.title,
                        tint: NSColor(list.noteColor.tint),
                        font: settings.nsFont(size: 13.5, weight: .medium),
                        previewWidth: max(rowSize.width, 220),
                        onClick: {
                            selectedTaskID = task.id
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                expandedTaskID = isExpanded ? nil : task.id
                            }
                        },
                        onDragBegan: {
                            selectedTaskID = task.id
                            expandedTaskID = nil
                            coordinator.beginTaskDrag(task)
                        },
                        onDragEnded: {
                            coordinator.endTaskDrag()
                        }
                    )
                }
            }

            if isHovering && !isEditing {
                Button {
                    coordinator.deleteTask(task)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete task")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func beginEditing() {
        selectedTaskID = task.id
        editingTaskID = task.id
    }

    private func completeTask() {
        if expandedTaskID == task.id {
            expandedTaskID = nil
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.34)) {
            coordinator.toggleTask(task)
        }
    }

    private func commitEditing() {
        guard isEditing else { return }
        coordinator.renameTask(task, to: titleDraft)
        editingTaskID = nil
        isTitleFocused = false
    }

    private func cancelEditing() {
        titleDraft = task.title
        editingTaskID = nil
        isTitleFocused = false
    }
}

private struct TaskRowDropDelegate: DropDelegate {
    let targetTask: TodoTask
    let targetList: TodoList
    let coordinator: WindowCoordinator
    let targetHeight: CGFloat
    let reduceMotion: Bool

    func validateDrop(info: DropInfo) -> Bool {
        coordinator.draggedTaskID != nil
    }

    func dropEntered(info: DropInfo) {
        updateDrop(info)
    }

    func dropExited(info: DropInfo) {
        coordinator.clearTaskDropTarget(targetTask.id)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDrop(info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        coordinator.endTaskDrag()
        return true
    }

    private func updateDrop(_ info: DropInfo) {
        guard let draggedTaskID = coordinator.draggedTaskID,
              draggedTaskID != targetTask.id else { return }

        let rowHeight = max(targetHeight, 30)
        let edge: TaskDropEdge = info.location.y < rowHeight / 2 ? .top : .bottom
        coordinator.updateTaskDropTarget(targetTask: targetTask, edge: edge)

        _ = withAnimation(
            reduceMotion ? nil : .interactiveSpring(response: 0.24, dampingFraction: 0.86)
        ) {
            coordinator.moveTask(
                id: draggedTaskID,
                to: targetList,
                relativeTo: targetTask,
                edge: edge,
                persistImmediately: false
            )
        }
    }
}

struct TaskListDropDelegate: DropDelegate {
    let targetList: TodoList
    let coordinator: WindowCoordinator
    let reduceMotion: Bool

    func validateDrop(info: DropInfo) -> Bool {
        coordinator.draggedTaskID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTaskID = coordinator.draggedTaskID else { return false }
        _ = withAnimation(reduceMotion ? nil : .snappy(duration: 0.20)) {
            coordinator.moveTask(
                id: draggedTaskID,
                to: targetList,
                persistImmediately: false
            )
        }
        coordinator.endTaskDrag()
        return true
    }
}
