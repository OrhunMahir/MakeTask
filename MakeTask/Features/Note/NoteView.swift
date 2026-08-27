import SwiftUI
import UniformTypeIdentifiers

struct NoteView: View {
    @Bindable var list: TodoList

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var newTaskTitle = ""
    @State private var isConfirmingDelete = false
    @State private var isConfirmingClearCompleted = false
    @State private var selectedTaskID: UUID?
    @State private var editingTaskID: UUID?
    @State private var expandedTaskID: UUID?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var taskRowFrames: [UUID: CGRect] = [:]
    @State private var taskViewportHeight: CGFloat = 0
    @State private var selectionMovement = 0
    @FocusState private var isNewTaskFocused: Bool
    @FocusState private var isSearchFocused: Bool

    private var activeTasks: [TodoTask] {
        list.orderedTasks.filter { !$0.isCompleted && matchesSearch($0) }
    }

    private var completedTasks: [TodoTask] {
        list.orderedTasks.filter { $0.isCompleted && matchesSearch($0) }
    }

    private var keyboardTasks: [TodoTask] {
        let canSelectCompleted = !settings.hideCompletedTasks && !list.isCompletedSectionCollapsed
        return activeTasks + (canSelectCompleted ? completedTasks : [])
    }

    private var visibleCompletedTasks: [TodoTask] {
        settings.hideCompletedTasks ? [] : completedTasks
    }

    private var taskOrderAnimationValue: [UUID] {
        list.orderedTasks.map(\.id)
    }

    private var taskCompletionAnimationValue: [String] {
        list.orderedTasks.map { "\($0.id.uuidString)-\($0.isCompleted)" }
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
                            } else if activeTasks.isEmpty && visibleCompletedTasks.isEmpty {
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
                                        editingTaskID: $editingTaskID,
                                        expandedTaskID: $expandedTaskID
                                    )
                                }

                                if !visibleCompletedTasks.isEmpty {
                                    completedHeader

                                    if !list.isCompletedSectionCollapsed {
                                        VStack(spacing: 0) {
                                            ForEach(visibleCompletedTasks) { task in
                                                TaskRowView(
                                                    task: task,
                                                    list: list,
                                                    selectedTaskID: $selectedTaskID,
                                                    editingTaskID: $editingTaskID,
                                                    expandedTaskID: $expandedTaskID
                                                )
                                            }
                                        }
                                        .transition(
                                            reduceMotion ? .opacity : .asymmetric(
                                                insertion: .opacity.combined(with: .offset(y: -12)),
                                                removal: .opacity.combined(with: .offset(y: -26))
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .animation(
                            reduceMotion
                                ? nil
                                : .interactiveSpring(response: 0.24, dampingFraction: 0.86),
                            value: taskOrderAnimationValue
                        )
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.34),
                            value: taskCompletionAnimationValue
                        )
                    }
                    .coordinateSpace(name: "task-scroll-\(list.id.uuidString)")
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TaskViewportHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: TaskListDropDelegate(
                            targetList: list,
                            coordinator: coordinator,
                            reduceMotion: reduceMotion
                        )
                    )
                    .onChange(of: selectedTaskID) { _, taskID in
                        guard let taskID else { return }
                        keepSelectionVisible(taskID, using: scrollProxy)
                    }
                    .onPreferenceChange(TaskRowFramePreferenceKey.self) { frames in
                        taskRowFrames = frames
                    }
                    .onPreferenceChange(TaskViewportHeightPreferenceKey.self) { height in
                        taskViewportHeight = height
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: isSearching)
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
            if let expandedTaskID, !taskIDs.contains(expandedTaskID),
               !completedTasks.contains(where: { $0.id == expandedTaskID }) {
                self.expandedTaskID = nil
            }
        }
        .confirmationDialog(
            "Delete “\(list.title)”?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete List", role: .destructive) {
                coordinator.deleteList(list)
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The list and all of its tasks will be deleted. Press ⌘Z immediately afterward to undo.")
        }
        .confirmationDialog(
            "Clear completed tasks?",
            isPresented: $isConfirmingClearCompleted
        ) {
            Button("Clear Completed Tasks", role: .destructive) {
                coordinator.clearCompletedTasks(in: list)
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All completed tasks in this list will be deleted. Press ⌘Z immediately afterward to undo.")
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
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
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
        Button {
            toggleCompletedSection()
        } label: {
            HStack(spacing: 6) {
                Image(
                    systemName: list.isCompletedSectionCollapsed
                        ? "chevron.right"
                        : "chevron.down"
                )
                .font(.system(size: 8.5, weight: .bold))
                .frame(width: 8)

                Text("Completed")
                    .font(.system(size: 10.5, weight: .semibold))
                    .textCase(.uppercase)

                Text("\(visibleCompletedTasks.count)")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 0.5)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .zIndex(1)
        .help(list.isCompletedSectionCollapsed ? "Show completed tasks" : "Hide completed tasks")
    }

    private func matchesSearch(_ task: TodoTask) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty
            || task.title.localizedCaseInsensitiveContains(query)
            || task.notes.localizedCaseInsensitiveContains(query)
            || task.subtasks.contains { $0.title.localizedCaseInsensitiveContains(query) }
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
            if expandedTaskID == task.id {
                expandedTaskID = nil
            }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.34)) {
                coordinator.toggleTask(task)
            }
        case .editSelectedTask:
            guard let task = selectedTask(orSelectFirst: true) else { return }
            editingTaskID = task.id
        case .deleteSelectedTask:
            guard let task = selectedTask(orSelectFirst: false) else { return }
            expandedTaskID = nil
            editingTaskID = nil
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                coordinator.deleteTask(task)
            }
        case .moveSelectedTaskUp:
            moveSelectedTask(by: -1)
        case .moveSelectedTaskDown:
            moveSelectedTask(by: 1)
        case .moveSelectedTaskToPreviousList:
            guard let task = selectedTask(orSelectFirst: false) else { return }
            coordinator.moveTaskToAdjacentList(task, by: -1)
        case .moveSelectedTaskToNextList:
            guard let task = selectedTask(orSelectFirst: false) else { return }
            coordinator.moveTaskToAdjacentList(task, by: 1)
        case .toggleCompletedSection:
            toggleCompletedSection()
        case .requestClearCompletedTasks:
            guard !completedTasks.isEmpty else { return }
            isConfirmingClearCompleted = true
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
            selectionMovement = offset
            self.selectedTaskID = offset < 0 ? keyboardTasks.last?.id : keyboardTasks.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), keyboardTasks.count - 1)
        guard nextIndex != currentIndex else { return }
        selectionMovement = offset
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
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.20)) {
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

    private func toggleCompletedSection() {
        guard !visibleCompletedTasks.isEmpty else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            list.isCompletedSectionCollapsed.toggle()
            if list.isCompletedSectionCollapsed,
               let selectedTaskID,
               completedTasks.contains(where: { $0.id == selectedTaskID }) {
                self.selectedTaskID = activeTasks.last?.id
            }
        }
        coordinator.saveContext()
    }

    private func keepSelectionVisible(_ taskID: UUID, using scrollProxy: ScrollViewProxy) {
        guard selectionMovement != 0 else { return }
        let movement = selectionMovement

        DispatchQueue.main.async {
            defer { selectionMovement = 0 }

            guard let frame = taskRowFrames[taskID], taskViewportHeight > 0 else {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                    scrollProxy.scrollTo(taskID, anchor: movement > 0 ? .bottom : .top)
                }
                return
            }

            let viewportMargin: CGFloat = 3
            if frame.minY < viewportMargin {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                    scrollProxy.scrollTo(taskID, anchor: .top)
                }
            } else if frame.maxY > taskViewportHeight - viewportMargin {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                    scrollProxy.scrollTo(taskID, anchor: .bottom)
                }
            }
        }
    }
}
