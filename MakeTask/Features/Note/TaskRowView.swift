import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TodoTask
    let list: TodoList

    @EnvironmentObject private var coordinator: WindowCoordinator
    @State private var isHovering = false
    @GestureState private var isPressing = false

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
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(list.noteColor.tint.opacity(isPressing ? 0.14 : 0))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    list.noteColor.tint.opacity(isPressing ? 0.95 : 0),
                    lineWidth: isPressing ? 1.5 : 0
                )
        }
        .scaleEffect(isPressing ? 1.012 : 1)
        .animation(.easeOut(duration: 0.12), value: isPressing)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.10)
                .updating($isPressing) { isPressed, state, _ in
                    state = isPressed
                }
        )
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
        .dropDestination(for: String.self) { items, _ in
            guard let rawID = items.first, let id = UUID(uuidString: rawID) else { return false }
            withAnimation(.snappy(duration: 0.22)) {
                coordinator.moveTask(id: id, to: list, before: task)
            }
            return true
        }
    }
}
