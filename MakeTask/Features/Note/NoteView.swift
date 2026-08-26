import SwiftUI
import UniformTypeIdentifiers

struct NoteView: View {
    @Bindable var list: TodoList

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @State private var newTaskTitle = ""
    @State private var isConfirmingDelete = false
    @State private var selectedTaskID: UUID?
    @State private var editingTaskID: UUID?
    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var isNewTaskFocused: Bool
    @FocusState private var isSearchFocused: Bool

    private var activeTasks: [TodoTask] {
        list.orderedTasks.filter { !$0.isCompleted && matchesSearch($0) }
    }

    private var completedTasks: [TodoTask] {
        list.orderedTasks.filter { $0.isCompleted && matchesSearch($0) }
    }

    private var keyboardTasks: [TodoTask] {
        activeTasks + (settings.hideCompletedTasks ? [] : completedTasks)
    }

    var body: some View {
        VStack(spacing: 0) {
            NoteHeaderView(
                list: list,
                isConfirmingDelete: $isConfirmingDelete
            )

            if !list.isCollapsed {
                Divider().opacity(0.45)

                if isSearching {
                    searchField
                    Divider().opacity(0.35)
                }

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if list.tasks.isEmpty {
                                emptyState(title: "No tasks yet", icon: "checklist")
                            } else if keyboardTasks.isEmpty {
                                emptyState(
                                    title: hasSearchQuery ? "No matching tasks" : "No active tasks",
                                    icon: hasSearchQuery ? "magnifyingglass" : "checkmark.circle"
                                )
                            } else {
                                ForEach(activeTasks) { task in
                                    TaskRowView(
                                        task: task,
                                        list: list,
                                        selectedTaskID: $selectedTaskID,
                                        editingTaskID: $editingTaskID
                                    )
                                }

                                if !settings.hideCompletedTasks && !completedTasks.isEmpty {
                                    completedHeader
                                    ForEach(completedTasks) { task in
                                        TaskRowView(
                                            task: task,
                                            list: list,
                                            selectedTaskID: $selectedTaskID,
                                            editingTaskID: $editingTaskID
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: TaskListDropDelegate(targetList: list, coordinator: coordinator)
                    )
                    .onChange(of: selectedTaskID) { _, taskID in
                        guard let taskID else { return }
                        withAnimation(.easeInOut(duration: 0.16)) {
                            scrollProxy.scrollTo(taskID, anchor: .center)
                        }
                    }
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
        .animation(.easeInOut(duration: 0.16), value: isSearching)
        .onReceive(coordinator.$focusNewTaskListID) { listID in
            guard listID == list.id, !list.isCollapsed else { return }
            isNewTaskFocused = true
        }
        .onReceive(coordinator.$noteKeyboardCommand) { event in
            guard let event, event.listID == list.id else { return }
            handleKeyboardCommand(event.command)
        }
        .onChange(of: keyboardTasks.map(\.id)) { _, taskIDs in
            if let selectedTaskID, !taskIDs.contains(selectedTaskID) {
                self.selectedTaskID = taskIDs.first
            }
            if let editingTaskID, !taskIDs.contains(editingTaskID) {
                self.editingTaskID = nil
            }
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
            Text("The list and all of its tasks will be deleted. Press ⌘Z immediately afterward to undo.")
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search tasks", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isSearchFocused)
                .onExitCommand(perform: closeSearch)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }

            Button {
                closeSearch()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close search")
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.primary.opacity(0.035))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func emptyState(title: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
            Text(title)
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

    private func matchesSearch(_ task: TodoTask) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || task.title.localizedCaseInsensitiveContains(query)
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleKeyboardCommand(_ command: NoteKeyboardCommand) {
        switch command {
        case .search:
            isSearching = true
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        case .selectPreviousTask:
            moveSelection(by: -1)
        case .selectNextTask:
            moveSelection(by: 1)
        case .toggleSelectedTask:
            guard let task = selectedTask(orSelectFirst: true) else { return }
            coordinator.toggleTask(task)
        case .editSelectedTask:
            guard let task = selectedTask(orSelectFirst: true) else { return }
            editingTaskID = task.id
        case .moveSelectedTaskUp:
            moveSelectedTask(by: -1)
        case .moveSelectedTaskDown:
            moveSelectedTask(by: 1)
        case .requestListDeletion:
            isConfirmingDelete = true
        }
    }

    private func moveSelection(by offset: Int) {
        guard !keyboardTasks.isEmpty else {
            selectedTaskID = nil
            return
        }

        guard let selectedTaskID,
              let currentIndex = keyboardTasks.firstIndex(where: { $0.id == selectedTaskID }) else {
            self.selectedTaskID = offset < 0 ? keyboardTasks.last?.id : keyboardTasks.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), keyboardTasks.count - 1)
        self.selectedTaskID = keyboardTasks[nextIndex].id
    }

    private func moveSelectedTask(by offset: Int) {
        guard let selectedTaskID,
              let currentIndex = keyboardTasks.firstIndex(where: { $0.id == selectedTaskID }) else {
            self.selectedTaskID = keyboardTasks.first?.id
            return
        }

        let targetIndex = currentIndex + offset
        guard keyboardTasks.indices.contains(targetIndex) else { return }
        withAnimation(.snappy(duration: 0.20)) {
            coordinator.swapTaskPositions(keyboardTasks[currentIndex], keyboardTasks[targetIndex])
        }
    }

    private func selectedTask(orSelectFirst: Bool) -> TodoTask? {
        if let selectedTaskID,
           let task = keyboardTasks.first(where: { $0.id == selectedTaskID }) {
            return task
        }
        guard orSelectFirst, let first = keyboardTasks.first else { return nil }
        selectedTaskID = first.id
        return first
    }

    private func closeSearch() {
        searchText = ""
        isSearching = false
        isSearchFocused = false
    }
}
