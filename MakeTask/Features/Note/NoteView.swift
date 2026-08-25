import SwiftUI

struct NoteView: View {
    @Bindable var list: TodoList

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @State private var newTaskTitle = ""
    @State private var renameTitle = ""
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    @FocusState private var isNewTaskFocused: Bool

    private var activeTasks: [TodoTask] {
        list.orderedTasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TodoTask] {
        list.orderedTasks.filter(\.isCompleted)
    }

    var body: some View {
        VStack(spacing: 0) {
            NoteHeaderView(
                list: list,
                isRenaming: $isRenaming,
                isConfirmingDelete: $isConfirmingDelete
            )

            if !list.isCollapsed {
                Divider().opacity(0.45)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if list.tasks.isEmpty {
                            emptyState
                        } else {
                            ForEach(activeTasks) { task in
                                TaskRowView(task: task, list: list)
                            }

                            if !settings.hideCompletedTasks && !completedTasks.isEmpty {
                                completedHeader
                                ForEach(completedTasks) { task in
                                    TaskRowView(task: task, list: list)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let rawID = items.first, let id = UUID(uuidString: rawID) else { return false }
                    coordinator.moveTask(id: id, to: list)
                    return true
                }

                Divider().opacity(0.45)

                NewTaskField(
                    list: list,
                    title: $newTaskTitle,
                    isFocused: $isNewTaskFocused
                )
            }
        }
        .background(NoteBackground(color: list.noteColor))
        .clipShape(RoundedRectangle(cornerRadius: NoteWindowMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NoteWindowMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
        }
        .animation(.easeInOut(duration: 0.18), value: list.isCollapsed)
        .onReceive(coordinator.$focusNewTaskListID) { listID in
            guard listID == list.id, !list.isCollapsed else { return }
            isNewTaskFocused = true
        }
        .onChange(of: isRenaming) { _, isPresented in
            if isPresented { renameTitle = list.title }
        }
        .alert("Rename List", isPresented: $isRenaming) {
            TextField("List name", text: $renameTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                coordinator.renameList(list, to: renameTitle)
            }
        } message: {
            Text("Choose a name for this desktop note.")
        }
        .confirmationDialog(
            "Delete “\(list.title)”?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete List", role: .destructive) {
                coordinator.deleteList(list)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The list and all of its tasks will be permanently deleted.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
            Text("No tasks yet")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var completedHeader: some View {
        HStack(spacing: 6) {
            Text("Completed")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
