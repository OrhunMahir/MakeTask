import AppKit
import Carbon.HIToolbox
import Combine
import SwiftData

enum NoteKeyboardCommand: Equatable {
    case search
    case selectPreviousTask
    case selectNextTask
    case toggleSelectedTask
    case editSelectedTask
    case deleteSelectedTask
    case moveSelectedTaskUp
    case moveSelectedTaskDown
    case moveSelectedTaskToPreviousList
    case moveSelectedTaskToNextList
    case toggleCompletedSection
    case requestClearCompletedTasks
    case requestListDeletion
}

enum TaskDropEdge: Equatable {
    case top
    case bottom
}

struct NoteKeyboardCommandEvent {
    let id = UUID()
    let listID: UUID
    let command: NoteKeyboardCommand
}

@MainActor
final class WindowCoordinator: ObservableObject {
    let modelContainer: ModelContainer
    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginService

    @Published private(set) var activeListID: UUID?
    @Published var focusNewTaskListID: UUID?
    @Published var renameListID: UUID?
    @Published var noteKeyboardCommand: NoteKeyboardCommandEvent?
    @Published private(set) var draggedTaskID: UUID?
    @Published private(set) var taskDropTargetID: UUID?
    @Published private(set) var taskDropEdge: TaskDropEdge = .top
    @Published private(set) var dueDateReferenceDate = Date()
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var errorMessage: String?

    private let context: ModelContext
    private var noteWindows: [UUID: NoteWindowController] = [:]
    private var quickAddWindow: QuickAddWindowController?
    private var quickAddHotKeyService: GlobalHotKeyService?
    private var visibilityHotKeyService: GlobalHotKeyService?
    private var localKeyMonitor: Any?
    private var taskDragSnapshot: [TaskPositionSnapshot]?
    private var taskDragCurrentPositions: [UUID: TaskPositionSnapshot]?
    private var taskDragDidMove = false
    private var taskDragCleanup: DispatchWorkItem?
    private var dueDateRefreshWorkItem: DispatchWorkItem?
    private var undoActions: [UndoAction] = []
    private var redoActions: [UndoAction] = []
    private var isPerformingHistoryAction = false

    private struct UndoAction {
        let name: String
        let undo: () -> Void
        let redo: () -> Void
    }

    private struct TaskPositionSnapshot {
        let taskID: UUID
        let listID: UUID?
        let sortOrder: Double
    }

    private struct SubtaskSnapshot {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let completedAt: Date?
        let createdAt: Date
        let sortOrder: Double

        init(subtask: TodoSubtask) {
            id = subtask.id
            title = subtask.title
            isCompleted = subtask.isCompleted
            completedAt = subtask.completedAt
            createdAt = subtask.createdAt
            sortOrder = subtask.sortOrder
        }
    }

    private struct TaskSnapshot {
        let id: UUID
        let title: String
        let notes: String
        let dueDate: Date?
        let priority: Int
        let isCompleted: Bool
        let completedAt: Date?
        let createdAt: Date
        let sortOrder: Double
        let listID: UUID?
        let subtasks: [SubtaskSnapshot]

        init(task: TodoTask) {
            id = task.id
            title = task.title
            notes = task.notes
            dueDate = task.dueDate
            priority = task.priority
            isCompleted = task.isCompleted
            completedAt = task.completedAt
            createdAt = task.createdAt
            sortOrder = task.sortOrder
            listID = task.list?.id
            subtasks = task.orderedSubtasks.map(SubtaskSnapshot.init)
        }
    }

    private struct ListSnapshot {
        let id: UUID
        let title: String
        let color: NoteColor
        let sortOrder: Double
        let createdAt: Date
        let windowX: Double?
        let windowTop: Double?
        let windowWidth: Double
        let windowHeight: Double
        let isCollapsed: Bool
        let isCompletedSectionCollapsed: Bool
        let isHidden: Bool
        let windowMode: WindowMode
        let tasks: [TaskSnapshot]
        let wasDefaultList: Bool
        let wasLastQuickCaptureList: Bool

        @MainActor
        init(list: TodoList, settings: AppSettings) {
            id = list.id
            title = list.title
            color = list.noteColor
            sortOrder = list.sortOrder
            createdAt = list.createdAt
            windowX = list.windowX
            windowTop = list.windowTop
            windowWidth = list.windowWidth
            windowHeight = list.windowHeight
            isCollapsed = list.isCollapsed
            isCompletedSectionCollapsed = list.isCompletedSectionCollapsed
            isHidden = list.isHidden
            windowMode = list.windowMode
            tasks = list.tasks.map(TaskSnapshot.init)
            wasDefaultList = settings.defaultListID == list.id
            wasLastQuickCaptureList = settings.lastQuickCaptureListID == list.id
        }
    }

    init(
        modelContainer: ModelContainer,
        settings: AppSettings,
        launchAtLogin: LaunchAtLoginService
    ) {
        self.modelContainer = modelContainer
        self.context = modelContainer.mainContext
        self.settings = settings
        self.launchAtLogin = launchAtLogin
    }

    func start() {
        migrateLegacyWindowDefaultsIfNeeded()

        do {
            let quickAddService = try GlobalHotKeyService(identifier: 1)
            quickAddService.onPressed = { [weak self] in
                self?.presentQuickAdd()
            }
            quickAddHotKeyService = quickAddService
            reloadGlobalShortcut()

            let visibilityService = try GlobalHotKeyService(identifier: 2)
            visibilityService.onPressed = { [weak self] in
                self?.toggleAllNotesVisibility()
            }
            try visibilityService.register(
                keyCode: UInt32(kVK_ANSI_H),
                modifiers: UInt32(cmdKey | shiftKey)
            )
            visibilityHotKeyService = visibilityService
        } catch {
            errorMessage = error.localizedDescription
        }

        installLocalKeyMonitor()
        restoreVisibleNotes()
        scheduleNextDueDateRefresh()
    }

    func stop() {
        quickAddHotKeyService?.unregister()
        visibilityHotKeyService?.unregister()
        dueDateRefreshWorkItem?.cancel()
        dueDateRefreshWorkItem = nil
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    func restoreVisibleNotes() {
        let descriptor = FetchDescriptor<TodoList>(
            sortBy: [SortDescriptor(\TodoList.sortOrder)]
        )
        do {
            for list in try context.fetch(descriptor) where !list.isHidden {
                show(list)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func createList(title: String? = nil) -> TodoList {
        let existing = fetchLists()
        let name = title ?? uniqueNewListName(in: existing)
        let order = (existing.map(\.sortOrder).max() ?? -1) + 1
        let color = NoteColor.allCases[existing.count % NoteColor.allCases.count]
        let list = TodoList(title: name, color: color, sortOrder: order)
        context.insert(list)

        if settings.defaultListID == nil {
            settings.defaultListID = list.id
        }
        if settings.lastQuickCaptureListID == nil {
            settings.lastQuickCaptureListID = list.id
        }

        saveContext()
        show(list)
        noteWindows[list.id]?.activateAndFocus()
        if title == nil {
            renameListID = list.id
        }
        let createdListID = list.id
        let snapshot = ListSnapshot(list: list, settings: settings)
        registerUndoAction(
            named: "Create List",
            undo: { [weak self] in
                guard let self, let createdList = self.fetchList(id: createdListID) else { return }
                self.deleteListWithoutRegisteringUndo(createdList)
            },
            redo: { [weak self] in
                self?.restoreList(from: snapshot)
            }
        )
        return list
    }

    func deleteList(_ list: TodoList) {
        let snapshot = ListSnapshot(list: list, settings: settings)
        deleteListWithoutRegisteringUndo(list)
        registerUndoAction(
            named: "Delete List",
            undo: { [weak self] in
                self?.restoreList(from: snapshot)
            },
            redo: { [weak self] in
                guard let self, let restoredList = self.fetchList(id: snapshot.id) else { return }
                self.deleteListWithoutRegisteringUndo(restoredList)
            }
        )
    }

    private func deleteListWithoutRegisteringUndo(_ list: TodoList) {
        noteWindows[list.id]?.hide()
        noteWindows[list.id] = nil

        if settings.defaultListID == list.id {
            settings.defaultListID = nil
        }
        if settings.lastQuickCaptureListID == list.id {
            settings.lastQuickCaptureListID = nil
        }
        if activeListID == list.id {
            activeListID = nil
        }

        context.delete(list)
        scheduleNextDueDateRefresh()
        saveContext()
    }

    func renameList(_ list: TodoList, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTitle = list.title
        let listID = list.id
        guard !trimmed.isEmpty, trimmed != previousTitle else { return }
        list.title = trimmed
        saveContext()
        registerUndoAction(
            named: "Rename List",
            undo: { [weak self] in
                self?.fetchList(id: listID)?.title = previousTitle
            },
            redo: { [weak self] in
                self?.fetchList(id: listID)?.title = trimmed
            }
        )
    }

    func setColor(_ color: NoteColor, for list: TodoList) {
        list.noteColor = color
        saveContext()
    }

    func setWindowMode(_ mode: WindowMode, for list: TodoList) {
        list.windowMode = mode
        noteWindows[list.id]?.applyWindowMode()
        saveContext()
    }

    func show(_ list: TodoList) {
        list.isHidden = false

        if let controller = noteWindows[list.id] {
            controller.show()
        } else {
            let controller = NoteWindowController(
                list: list,
                frame: restoredFrame(for: list),
                modelContainer: modelContainer,
                coordinator: self,
                settings: settings
            )
            noteWindows[list.id] = controller
            controller.show()
        }
        saveContext()
    }

    func showAndActivate(_ list: TodoList) {
        show(list)
        noteWindows[list.id]?.activateAndFocus()
    }

    func hide(_ list: TodoList) {
        list.isHidden = true
        noteWindows[list.id]?.hide()
        saveContext()
    }

    func toggleVisibility(of list: TodoList) {
        list.isHidden ? showAndActivate(list) : hide(list)
    }

    func showAll() {
        let lists = fetchLists()
        lists.forEach(show)
        if let firstList = lists.first {
            noteWindows[firstList.id]?.activateAndFocus()
        }
    }

    func hideAll() {
        fetchLists().forEach(hide)
    }

    func toggleAllNotesVisibility() {
        let lists = fetchLists()
        guard !lists.isEmpty else {
            presentQuickAdd()
            return
        }

        if lists.allSatisfy({ !$0.isHidden }) {
            lists.forEach(hide)
        } else {
            lists.forEach(show)
            if let firstList = lists.first {
                noteWindows[firstList.id]?.activateAndFocus()
            }
        }
    }

    func toggleCollapse(_ list: TodoList) {
        guard let controller = noteWindows[list.id] else {
            show(list)
            noteWindows[list.id]?.setCollapsed(!list.isCollapsed, animated: true)
            return
        }
        controller.setCollapsed(!list.isCollapsed, animated: true)
    }

    func collapseActiveNote() {
        guard let list = activeList() else { return }
        toggleCollapse(list)
    }

    func hideActiveNote() {
        guard let list = activeList() else { return }
        hide(list)
    }

    func noteDidBecomeActive(_ list: TodoList) {
        activeListID = list.id
    }

    func focusNewTaskInActiveNote() {
        let list = activeList() ?? fetchLists().first
        guard let list else {
            _ = createList()
            return
        }
        show(list)
        noteWindows[list.id]?.activateAndFocus()
        focusNewTaskListID = list.id
    }

    func activateList(at index: Int) {
        let lists = fetchLists()
        guard lists.indices.contains(index) else { return }
        showAndActivate(lists[index])
    }

    func beginRenamingActiveList() {
        guard let list = activeList() else { return }
        showAndActivate(list)
        renameListID = list.id
    }

    func sendKeyboardCommand(_ command: NoteKeyboardCommand, activatingNote: Bool = false) {
        guard let list = activeList() else { return }
        if activatingNote || list.isHidden {
            showAndActivate(list)
        }
        if list.isCollapsed, command != .requestListDeletion {
            toggleCollapse(list)
        }
        noteKeyboardCommand = NoteKeyboardCommandEvent(listID: list.id, command: command)
    }

    func addTask(title: String, to list: TodoList) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let order = (list.tasks.map(\.sortOrder).max() ?? -1) + 1
        let task = TodoTask(title: trimmed, sortOrder: order, list: list)
        context.insert(task)
        saveContext()
        let snapshot = TaskSnapshot(task: task)
        registerUndoAction(
            named: "Add Task",
            undo: { [weak self] in
                guard let self, let currentTask = self.fetchTask(id: snapshot.id) else { return }
                self.context.delete(currentTask)
            },
            redo: { [weak self] in
                self?.restoreTask(from: snapshot)
            }
        )
    }

    func toggleTask(_ task: TodoTask) {
        let previousCompleted = task.isCompleted
        let previousCompletedAt = task.completedAt
        let taskID = task.id
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        let updatedCompleted = task.isCompleted
        let updatedCompletedAt = task.completedAt
        if task.isCompleted {
            settings.playCompletionSound()
        }
        scheduleNextDueDateRefresh()
        saveContext()
        registerUndoAction(
            named: task.isCompleted ? "Complete Task" : "Uncomplete Task",
            undo: { [weak self] in
                guard let currentTask = self?.fetchTask(id: taskID) else { return }
                currentTask.isCompleted = previousCompleted
                currentTask.completedAt = previousCompletedAt
            },
            redo: { [weak self] in
                guard let currentTask = self?.fetchTask(id: taskID) else { return }
                currentTask.isCompleted = updatedCompleted
                currentTask.completedAt = updatedCompletedAt
            }
        )
    }

    func deleteTask(_ task: TodoTask) {
        let snapshot = TaskSnapshot(task: task)
        context.delete(task)
        scheduleNextDueDateRefresh()
        saveContext()
        registerUndoAction(
            named: "Delete Task",
            undo: { [weak self] in
                self?.restoreTask(from: snapshot)
            },
            redo: { [weak self] in
                guard let self, let restoredTask = self.fetchTask(id: snapshot.id) else { return }
                self.context.delete(restoredTask)
            }
        )
    }

    func renameTask(_ task: TodoTask, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTitle = task.title
        let taskID = task.id
        guard !trimmed.isEmpty, trimmed != previousTitle else { return }
        task.title = trimmed
        saveContext()
        registerUndoAction(
            named: "Edit Task",
            undo: { [weak self] in
                self?.fetchTask(id: taskID)?.title = previousTitle
            },
            redo: { [weak self] in
                self?.fetchTask(id: taskID)?.title = trimmed
            }
        )
    }

    func setDueDate(_ dueDate: Date?, for task: TodoTask) {
        task.dueDate = dueDate
        scheduleNextDueDateRefresh()
        saveContext()
    }

    func setPriority(_ priority: TaskPriority, for task: TodoTask) {
        let previousPriority = task.priorityLevel
        let taskID = task.id
        guard priority != previousPriority else { return }

        task.priorityLevel = priority
        saveContext()
        registerUndoAction(
            named: "Change Priority",
            undo: { [weak self] in
                self?.fetchTask(id: taskID)?.priorityLevel = previousPriority
            },
            redo: { [weak self] in
                self?.fetchTask(id: taskID)?.priorityLevel = priority
            }
        )
    }

    func addSubtask(title: String, to task: TodoTask) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let order = (task.subtasks.map(\.sortOrder).max() ?? -1) + 1
        let subtask = TodoSubtask(title: trimmed, sortOrder: order, task: task)
        context.insert(subtask)
        saveContext()

        let snapshot = SubtaskSnapshot(subtask: subtask)
        let taskID = task.id
        registerUndoAction(
            named: "Add Subtask",
            undo: { [weak self] in
                guard let self, let currentSubtask = self.fetchSubtask(id: snapshot.id) else { return }
                self.context.delete(currentSubtask)
            },
            redo: { [weak self] in
                self?.restoreSubtask(from: snapshot, taskID: taskID)
            }
        )
    }

    func toggleSubtask(_ subtask: TodoSubtask) {
        let previousCompleted = subtask.isCompleted
        let previousCompletedAt = subtask.completedAt
        let subtaskID = subtask.id

        subtask.isCompleted.toggle()
        subtask.completedAt = subtask.isCompleted ? .now : nil
        let updatedCompleted = subtask.isCompleted
        let updatedCompletedAt = subtask.completedAt
        if subtask.isCompleted {
            settings.playSubtaskCompletionSound()
        }
        saveContext()

        registerUndoAction(
            named: subtask.isCompleted ? "Complete Subtask" : "Uncomplete Subtask",
            undo: { [weak self] in
                guard let currentSubtask = self?.fetchSubtask(id: subtaskID) else { return }
                currentSubtask.isCompleted = previousCompleted
                currentSubtask.completedAt = previousCompletedAt
            },
            redo: { [weak self] in
                guard let currentSubtask = self?.fetchSubtask(id: subtaskID) else { return }
                currentSubtask.isCompleted = updatedCompleted
                currentSubtask.completedAt = updatedCompletedAt
            }
        )
    }

    func renameSubtask(_ subtask: TodoSubtask, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTitle = subtask.title
        let subtaskID = subtask.id
        guard !trimmed.isEmpty, trimmed != previousTitle else { return }

        subtask.title = trimmed
        saveContext()
        registerUndoAction(
            named: "Edit Subtask",
            undo: { [weak self] in
                self?.fetchSubtask(id: subtaskID)?.title = previousTitle
            },
            redo: { [weak self] in
                self?.fetchSubtask(id: subtaskID)?.title = trimmed
            }
        )
    }

    func deleteSubtask(_ subtask: TodoSubtask) {
        guard let taskID = subtask.task?.id else { return }
        let snapshot = SubtaskSnapshot(subtask: subtask)
        context.delete(subtask)
        saveContext()

        registerUndoAction(
            named: "Delete Subtask",
            undo: { [weak self] in
                self?.restoreSubtask(from: snapshot, taskID: taskID)
            },
            redo: { [weak self] in
                guard let self, let restoredSubtask = self.fetchSubtask(id: snapshot.id) else { return }
                self.context.delete(restoredSubtask)
            }
        )
    }

    func clearCompletedTasks(in list: TodoList) {
        let snapshots = list.tasks.filter(\.isCompleted).map(TaskSnapshot.init)
        guard !snapshots.isEmpty else { return }

        for task in list.tasks where task.isCompleted {
            context.delete(task)
        }
        saveContext()

        registerUndoAction(
            named: "Clear Completed Tasks",
            undo: { [weak self] in
                guard let self else { return }
                snapshots.forEach { self.restoreTask(from: $0) }
            },
            redo: { [weak self] in
                guard let self else { return }
                for snapshot in snapshots {
                    if let task = self.fetchTask(id: snapshot.id) {
                        self.context.delete(task)
                    }
                }
            }
        )
    }

    func moveTaskToAdjacentList(_ task: TodoTask, by offset: Int) {
        guard let sourceList = task.list else { return }
        let lists = fetchLists()
        guard let sourceIndex = lists.firstIndex(where: { $0.id == sourceList.id }) else { return }
        let targetIndex = sourceIndex + offset
        guard lists.indices.contains(targetIndex) else { return }

        let beforeSnapshot = fetchTasks().map {
            TaskPositionSnapshot(taskID: $0.id, listID: $0.list?.id, sortOrder: $0.sortOrder)
        }
        guard moveTask(id: task.id, to: lists[targetIndex]) else { return }
        let afterSnapshot = fetchTasks().map {
            TaskPositionSnapshot(taskID: $0.id, listID: $0.list?.id, sortOrder: $0.sortOrder)
        }

        registerUndoAction(
            named: "Move Task Between Lists",
            undo: { [weak self] in self?.restoreTaskPositions(beforeSnapshot) },
            redo: { [weak self] in self?.restoreTaskPositions(afterSnapshot) }
        )
    }

    func swapTaskPositions(_ first: TodoTask, _ second: TodoTask) {
        let firstOrder = first.sortOrder
        let secondOrder = second.sortOrder
        let firstID = first.id
        let secondID = second.id
        first.sortOrder = secondOrder
        second.sortOrder = firstOrder
        saveContext()
        registerUndoAction(
            named: "Reorder Task",
            undo: { [weak self] in
                guard let currentFirst = self?.fetchTask(id: firstID),
                      let currentSecond = self?.fetchTask(id: secondID) else { return }
                currentFirst.sortOrder = firstOrder
                currentSecond.sortOrder = secondOrder
            },
            redo: { [weak self] in
                guard let currentFirst = self?.fetchTask(id: firstID),
                      let currentSecond = self?.fetchTask(id: secondID) else { return }
                currentFirst.sortOrder = secondOrder
                currentSecond.sortOrder = firstOrder
            }
        )
    }

    func beginTaskDrag(_ task: TodoTask) {
        guard draggedTaskID == nil else { return }
        draggedTaskID = task.id
        let snapshot = fetchTasks().map {
            TaskPositionSnapshot(taskID: $0.id, listID: $0.list?.id, sortOrder: $0.sortOrder)
        }
        taskDragSnapshot = snapshot
        taskDragCurrentPositions = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.taskID, $0) })
        taskDragDidMove = false
        taskDragCleanup?.cancel()
        let cleanup = DispatchWorkItem { [weak self] in
            self?.endTaskDrag()
        }
        taskDragCleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: cleanup)
    }

    func updateTaskDropTarget(targetTask: TodoTask, edge: TaskDropEdge) {
        taskDropTargetID = targetTask.id
        taskDropEdge = edge
    }

    func clearTaskDropTarget(_ taskID: UUID) {
        guard taskDropTargetID == taskID else { return }
        taskDropTargetID = nil
    }

    func endTaskDrag() {
        taskDragCleanup?.cancel()
        taskDragCleanup = nil
        taskDropTargetID = nil
        guard let beforeSnapshot = taskDragSnapshot else {
            draggedTaskID = nil
            return
        }
        let afterSnapshot = taskDragCurrentPositions.map { Array($0.values) } ?? []
        let finalPositions = Dictionary(uniqueKeysWithValues: afterSnapshot.map { ($0.taskID, $0) })
        let didMove = taskDragDidMove && beforeSnapshot.contains { previous in
            guard let current = finalPositions[previous.taskID] else { return true }
            return current.listID != previous.listID || current.sortOrder != previous.sortOrder
        }
        taskDragSnapshot = nil
        taskDragCurrentPositions = nil
        taskDragDidMove = false
        draggedTaskID = nil
        guard didMove else { return }

        registerUndoAction(
            named: "Move Task",
            undo: { [weak self] in self?.restoreTaskPositions(beforeSnapshot) },
            redo: { [weak self] in self?.restoreTaskPositions(afterSnapshot) }
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.saveContext()
        }
    }

    @discardableResult
    func moveTask(
        id: UUID,
        to targetList: TodoList,
        relativeTo targetTask: TodoTask? = nil,
        edge: TaskDropEdge = .bottom,
        persistImmediately: Bool = true
    ) -> Bool {
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return false }

        let sourceList = task.list
        var ordered = targetList.orderedTasks.filter { $0.id != task.id }
        if let targetTask,
           let index = ordered.firstIndex(where: { $0.id == targetTask.id }) {
            let insertionIndex = min(index + (edge == .bottom ? 1 : 0), ordered.count)
            ordered.insert(task, at: insertionIndex)
        } else {
            ordered.append(task)
        }

        let targetOrderChanged = ordered.map(\.id) != targetList.orderedTasks.map(\.id)
        guard sourceList?.id != targetList.id || targetOrderChanged else { return false }

        if sourceList?.id != targetList.id {
            task.list = targetList
        }
        for (index, item) in ordered.enumerated() {
            item.sortOrder = Double(index)
        }

        if let sourceList, sourceList.id != targetList.id {
            for (index, item) in sourceList.orderedTasks.enumerated() {
                item.sortOrder = Double(index)
            }
        }
        if !persistImmediately, draggedTaskID != nil {
            taskDragDidMove = true
            var changedTasks = ordered
            if let sourceList, sourceList.id != targetList.id {
                changedTasks.append(contentsOf: sourceList.orderedTasks)
            }
            for item in changedTasks {
                taskDragCurrentPositions?[item.id] = TaskPositionSnapshot(
                    taskID: item.id,
                    listID: item.list?.id,
                    sortOrder: item.sortOrder
                )
            }
        }
        if persistImmediately {
            saveContext()
        }
        return true
    }

    func presentQuickAdd() {
        if let quickAddWindow {
            quickAddWindow.present()
            return
        }

        let controller = QuickAddWindowController(
            modelContainer: modelContainer,
            coordinator: self,
            settings: settings
        )
        quickAddWindow = controller
        controller.present()
    }

    func dismissQuickAdd() {
        let controller = quickAddWindow
        quickAddWindow = nil
        controller?.dismiss()
    }

    func reloadGlobalShortcut() {
        guard settings.quickAddCarbonModifiers != 0 else {
            quickAddHotKeyService?.unregister()
            errorMessage = "The global shortcut needs at least one modifier key."
            return
        }
        do {
            try quickAddHotKeyService?.register(
                keyCode: settings.quickAddKeyCode,
                modifiers: settings.quickAddCarbonModifiers
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func undoLastAction() -> Bool {
        guard let action = undoActions.popLast() else { return false }
        isPerformingHistoryAction = true
        action.undo()
        isPerformingHistoryAction = false
        redoActions.append(action)
        updateHistoryAvailability()
        scheduleNextDueDateRefresh()
        saveContext()
        return true
    }

    @discardableResult
    func redoLastAction() -> Bool {
        guard let action = redoActions.popLast() else { return false }
        isPerformingHistoryAction = true
        action.redo()
        isPerformingHistoryAction = false
        undoActions.append(action)
        updateHistoryAvailability()
        scheduleNextDueDateRefresh()
        saveContext()
        return true
    }

    private func scheduleNextDueDateRefresh() {
        dueDateRefreshWorkItem?.cancel()
        dueDateRefreshWorkItem = nil

        let now = Date()
        dueDateReferenceDate = now
        let nextDueDate = fetchTasks()
            .filter { !$0.isCompleted }
            .compactMap(\.dueDate)
            .filter { $0 > now }
            .min()

        guard let nextDueDate else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.scheduleNextDueDateRefresh()
        }
        dueDateRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(nextDueDate.timeIntervalSince(now), 0.05) + 0.05,
            execute: workItem
        )
    }

    private func activeList() -> TodoList? {
        guard let activeListID else { return nil }
        return fetchLists().first { $0.id == activeListID }
    }

    private func installLocalKeyMonitor() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            var modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            modifiers.subtract([.capsLock, .function, .numericPad])
            let key = event.charactersIgnoringModifiers?.lowercased()
            let quickAddIsKey = self.quickAddWindow?.window?.isKeyWindow == true
            let notePanelIsKey = !quickAddIsKey && NSApp.keyWindow is FloatingNotePanel
            let isEditingText = NSApp.keyWindow?.firstResponder is NSTextView

            if key == "w", modifiers == [.command] {
                if quickAddIsKey {
                    self.dismissQuickAdd()
                    return nil
                }
                if notePanelIsKey {
                    self.hideActiveNote()
                    return nil
                }
            }

            if key == "m",
               modifiers == [.command],
               notePanelIsKey {
                self.collapseActiveNote()
                return nil
            }

            if key == "f", modifiers == [.command], notePanelIsKey {
                self.sendKeyboardCommand(.search)
                return nil
            }

            if key == "z", modifiers == [.command, .shift], !quickAddIsKey, !isEditingText {
                return self.redoLastAction() ? nil : event
            }

            if key == "z", modifiers == [.command], !quickAddIsKey, !isEditingText {
                return self.undoLastAction() ? nil : event
            }

            if key == "l", modifiers == [.command], notePanelIsKey, !isEditingText {
                self.beginRenamingActiveList()
                return nil
            }

            if key == "c", modifiers == [.command, .shift], notePanelIsKey, !isEditingText {
                self.sendKeyboardCommand(.toggleCompletedSection)
                return nil
            }

            if event.keyCode == UInt16(kVK_LeftArrow), modifiers == [.command, .control],
               notePanelIsKey, !isEditingText {
                self.sendKeyboardCommand(.moveSelectedTaskToPreviousList)
                return nil
            }

            if event.keyCode == UInt16(kVK_RightArrow), modifiers == [.command, .control],
               notePanelIsKey, !isEditingText {
                self.sendKeyboardCommand(.moveSelectedTaskToNextList)
                return nil
            }

            if (event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)),
               modifiers == [.command, .option], notePanelIsKey, !isEditingText, !event.isARepeat {
                self.sendKeyboardCommand(.requestClearCompletedTasks)
                return nil
            }

            if (event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)),
               modifiers == [.command], notePanelIsKey, !event.isARepeat {
                self.sendKeyboardCommand(.requestListDeletion)
                return nil
            }

            if (event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)),
               modifiers.isEmpty, notePanelIsKey, !isEditingText, !event.isARepeat {
                self.sendKeyboardCommand(.deleteSelectedTask)
                return nil
            }

            if event.keyCode == UInt16(kVK_UpArrow), modifiers.isEmpty, notePanelIsKey, !isEditingText {
                self.sendKeyboardCommand(.selectPreviousTask)
                return nil
            }

            if event.keyCode == UInt16(kVK_DownArrow), modifiers.isEmpty, notePanelIsKey, !isEditingText {
                self.sendKeyboardCommand(.selectNextTask)
                return nil
            }

            if event.keyCode == UInt16(kVK_Space), modifiers.isEmpty,
               notePanelIsKey, !isEditingText, !event.isARepeat {
                self.sendKeyboardCommand(.toggleSelectedTask)
                return nil
            }

            if (event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter)),
               modifiers.isEmpty, notePanelIsKey, !isEditingText, !event.isARepeat {
                self.sendKeyboardCommand(.editSelectedTask)
                return nil
            }

            if event.keyCode == UInt16(kVK_UpArrow), modifiers == [.option],
               notePanelIsKey, !isEditingText {
                self.sendKeyboardCommand(.moveSelectedTaskUp)
                return nil
            }

            if event.keyCode == UInt16(kVK_DownArrow), modifiers == [.option],
               notePanelIsKey, !isEditingText {
                self.sendKeyboardCommand(.moveSelectedTaskDown)
                return nil
            }

            if modifiers == [.command], !quickAddIsKey, !isEditingText,
               let key, let listNumber = Int(key), (1...9).contains(listNumber) {
                self.activateList(at: listNumber - 1)
                return nil
            }

            if key == "n", modifiers == [.command, .shift], !isEditingText {
                _ = self.createList()
                return nil
            }

            if key == "n", modifiers == [.command], !isEditingText {
                self.focusNewTaskInActiveNote()
                return nil
            }

            return event
        }
    }

    private func registerUndoAction(
        named name: String,
        undo: @escaping () -> Void,
        redo: @escaping () -> Void
    ) {
        guard !isPerformingHistoryAction else { return }
        undoActions.append(UndoAction(name: name, undo: undo, redo: redo))
        if undoActions.count > 50 {
            undoActions.removeFirst(undoActions.count - 50)
        }
        redoActions.removeAll()
        updateHistoryAvailability()
    }

    private func updateHistoryAvailability() {
        canUndo = !undoActions.isEmpty
        canRedo = !redoActions.isEmpty
    }

    private func restoreTask(from snapshot: TaskSnapshot) {
        guard fetchTask(id: snapshot.id) == nil else { return }
        let list = snapshot.listID.flatMap(fetchList(id:))
        let task = TodoTask(
            id: snapshot.id,
            title: snapshot.title,
            notes: snapshot.notes,
            dueDate: snapshot.dueDate,
            priority: snapshot.priority,
            isCompleted: snapshot.isCompleted,
            completedAt: snapshot.completedAt,
            createdAt: snapshot.createdAt,
            sortOrder: snapshot.sortOrder,
            list: list
        )
        context.insert(task)
        restoreSubtasks(snapshot.subtasks, for: task)
    }

    private func restoreList(from snapshot: ListSnapshot) {
        guard fetchList(id: snapshot.id) == nil else { return }
        let list = TodoList(
            id: snapshot.id,
            title: snapshot.title,
            color: snapshot.color,
            sortOrder: snapshot.sortOrder,
            createdAt: snapshot.createdAt,
            windowX: snapshot.windowX,
            windowTop: snapshot.windowTop,
            windowWidth: snapshot.windowWidth,
            windowHeight: snapshot.windowHeight,
            isCollapsed: snapshot.isCollapsed,
            isCompletedSectionCollapsed: snapshot.isCompletedSectionCollapsed,
            isHidden: snapshot.isHidden,
            windowMode: snapshot.windowMode
        )
        context.insert(list)

        for taskSnapshot in snapshot.tasks {
            let task = TodoTask(
                id: taskSnapshot.id,
                title: taskSnapshot.title,
                notes: taskSnapshot.notes,
                dueDate: taskSnapshot.dueDate,
                priority: taskSnapshot.priority,
                isCompleted: taskSnapshot.isCompleted,
                completedAt: taskSnapshot.completedAt,
                createdAt: taskSnapshot.createdAt,
                sortOrder: taskSnapshot.sortOrder,
                list: list
            )
            context.insert(task)
            restoreSubtasks(taskSnapshot.subtasks, for: task)
        }

        if snapshot.wasDefaultList {
            settings.defaultListID = list.id
        }
        if snapshot.wasLastQuickCaptureList {
            settings.lastQuickCaptureListID = list.id
        }
        if !snapshot.isHidden {
            show(list)
        }
    }

    private func restoreTaskPositions(_ snapshots: [TaskPositionSnapshot]) {
        let listsByID = Dictionary(uniqueKeysWithValues: fetchLists().map { ($0.id, $0) })
        for snapshot in snapshots {
            guard let task = fetchTask(id: snapshot.taskID) else { continue }
            task.list = snapshot.listID.flatMap { listsByID[$0] }
            task.sortOrder = snapshot.sortOrder
        }
    }

    private func fetchTask(id: UUID) -> TodoTask? {
        let descriptor = FetchDescriptor<TodoTask>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetchSubtask(id: UUID) -> TodoSubtask? {
        let descriptor = FetchDescriptor<TodoSubtask>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func restoreSubtask(from snapshot: SubtaskSnapshot, taskID: UUID) {
        guard fetchSubtask(id: snapshot.id) == nil,
              let task = fetchTask(id: taskID) else { return }
        restoreSubtasks([snapshot], for: task)
    }

    private func restoreSubtasks(_ snapshots: [SubtaskSnapshot], for task: TodoTask) {
        for snapshot in snapshots where fetchSubtask(id: snapshot.id) == nil {
            let subtask = TodoSubtask(
                id: snapshot.id,
                title: snapshot.title,
                isCompleted: snapshot.isCompleted,
                completedAt: snapshot.completedAt,
                createdAt: snapshot.createdAt,
                sortOrder: snapshot.sortOrder,
                task: task
            )
            context.insert(subtask)
        }
    }

    private func fetchTasks() -> [TodoTask] {
        let descriptor = FetchDescriptor<TodoTask>(sortBy: [SortDescriptor(\TodoTask.sortOrder)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchList(id: UUID) -> TodoList? {
        let descriptor = FetchDescriptor<TodoList>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetchLists() -> [TodoList] {
        let descriptor = FetchDescriptor<TodoList>(
            sortBy: [SortDescriptor(\TodoList.sortOrder)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    private func uniqueNewListName(in lists: [TodoList]) -> String {
        let existingNames = Set(lists.map { $0.title.lowercased() })
        if !existingNames.contains("new list") { return "New List" }

        var suffix = 2
        while existingNames.contains("new list \(suffix)") {
            suffix += 1
        }
        return "New List \(suffix)"
    }

    private func migrateLegacyWindowDefaultsIfNeeded() {
        let migrationKey = "MakeTask.didMigrateDefaultWindowModeToNormal.v1"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }

        for list in fetchLists() where list.windowMode == .desktop {
            list.windowMode = .normal
        }
        saveContext()
        defaults.set(true, forKey: migrationKey)
    }

    private func restoredFrame(for list: TodoList) -> NSRect {
        let width = max(list.windowWidth, NoteWindowMetrics.minimumWidth)
        let height = max(list.windowHeight, NoteWindowMetrics.headerHeight + 120)

        if let x = list.windowX, let top = list.windowTop {
            let candidate = NSRect(x: x, y: top - height, width: width, height: height)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(candidate) }) {
                return candidate
            }
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let cascade = CGFloat(noteWindows.count % 8) * 24
        return NSRect(
            x: visible.maxX - width - 24 - cascade,
            y: visible.maxY - height - 24 - cascade,
            width: width,
            height: height
        )
    }
}
