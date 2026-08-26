import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TaskRowView: View {
    @Bindable var task: TodoTask
    let list: TodoList
    @Binding var selectedTaskID: UUID?
    @Binding var editingTaskID: UUID?

    @EnvironmentObject private var coordinator: WindowCoordinator
    @State private var isHovering = false
    @State private var titleDraft = ""
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

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Button {
                selectedTaskID = task.id
                coordinator.toggleTask(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(task.isCompleted ? list.noteColor.tint : .secondary)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Mark incomplete" : "Mark complete")

            if isEditing {
                TextField("Task title", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .focused($isTitleFocused)
                    .onSubmit(commitEditing)
                    .onExitCommand(perform: cancelEditing)
            } else {
                Text(task.title)
                    .font(.system(size: 13.5))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTaskID = task.id
                        coordinator.toggleTask(task)
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
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(list.noteColor.tint.opacity(isDragging ? 0.18 : (isSelected ? 0.09 : 0)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    list.noteColor.tint.opacity(isDragging ? 1 : (isSelected ? 0.62 : 0)),
                    lineWidth: isDragging ? 2 : (isSelected ? 1 : 0)
                )
        }
        .scaleEffect(isDragging ? 1.012 : 1)
        .animation(.easeOut(duration: 0.12), value: isDragging)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit Task") {
                beginEditing()
            }
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                coordinator.toggleTask(task)
            }
            Divider()
            Button("Delete Task", role: .destructive) {
                coordinator.deleteTask(task)
            }
        }
        .onDrag {
            selectedTaskID = task.id
            coordinator.beginTaskDrag(task)
            return NSItemProvider(object: task.id.uuidString as NSString)
        } preview: {
            dragPreview
        }
        .onDrop(
            of: [UTType.text],
            delegate: TaskRowDropDelegate(
                targetTask: task,
                targetList: list,
                coordinator: coordinator
            )
        )
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

    private var dragPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(list.noteColor.tint)
            Text(task.title)
                .lineLimit(1)
        }
        .font(.system(size: 13.5, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(list.noteColor.tint.opacity(0.95), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    private func beginEditing() {
        selectedTaskID = task.id
        editingTaskID = task.id
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

    func validateDrop(info: DropInfo) -> Bool {
        coordinator.draggedTaskID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedTaskID = coordinator.draggedTaskID,
              draggedTaskID != targetTask.id else { return }

        withAnimation(.snappy(duration: 0.20)) {
            coordinator.moveTask(id: draggedTaskID, to: targetList, before: targetTask)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        coordinator.endTaskDrag()
        return true
    }
}

struct TaskListDropDelegate: DropDelegate {
    let targetList: TodoList
    let coordinator: WindowCoordinator

    func validateDrop(info: DropInfo) -> Bool {
        coordinator.draggedTaskID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTaskID = coordinator.draggedTaskID else { return false }
        withAnimation(.snappy(duration: 0.20)) {
            coordinator.moveTask(id: draggedTaskID, to: targetList)
        }
        coordinator.endTaskDrag()
        return true
    }
}
