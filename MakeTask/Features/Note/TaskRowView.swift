import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TodoTask
    let list: TodoList

    @EnvironmentObject private var coordinator: WindowCoordinator
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Button {
                coordinator.toggleTask(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(task.isCompleted ? list.noteColor.tint : .secondary)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Mark incomplete" : "Mark complete")

            Text(task.title)
                .font(.system(size: 13.5))
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    coordinator.toggleTask(task)
                }

            if isHovering {
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
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                coordinator.toggleTask(task)
            }
            Divider()
            Button("Delete Task", role: .destructive) {
                coordinator.deleteTask(task)
            }
        }
        .draggable(task.id.uuidString) {
            Text(task.title)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let rawID = items.first, let id = UUID(uuidString: rawID) else { return false }
            coordinator.moveTask(id: id, to: list, before: task)
            return true
        }
    }
}
