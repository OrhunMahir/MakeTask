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
    case moveSelectedTaskUp
    case moveSelectedTaskDown
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
    @Published private(set) var canUndo = false
    @Published var errorMessage: String?

    private let context: ModelContext
    private var noteWindows: [UUID: NoteWindowController] = [:]
    private var quickAddWindow: QuickAddWindowController?
    private var quickAddHotKeyService: GlobalHotKeyService?
    private var visibilityHotKeyService: GlobalHotKeyService?
    private var localKeyMonitor: Any?
    private var taskDragSnapshot: [TaskPositionSnapshot]?
    private var taskDragCleanup: DispatchWorkItem?
    private var undoActions: [UndoAction] = []
    private var isPerformingUndo = false

    private struct UndoAction {
        let name: String
        let perform: () -> Void
    }

    private struct TaskPositionSnapshot {
        let taskID: UUID
        let listID: UUID?
        let sortOrder: Double
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
    }

    func stop() {
        quickAddHotKeyService?.unregister()
        visibilityHotKeyService?.unregister()
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
        registerUndoAction(named: "Create List") { [weak self] in
            guard let self, let createdList = self.fetchList(id: createdListID) else { return }
            self.deleteListWithoutRegisteringUndo(createdList)
        }
        return list
    }

    func deleteList(_ list: TodoList) {
        let snapshot = ListSnapshot(list: list, settings: settings)
        deleteListWithoutRegisteringUndo(list)
        registerUndoAction(named: "Delete List") { [weak self] in
            self?.restoreList(from: snapshot)
        }
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
        saveContext()
    }

    func renameList(_ list: TodoList, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTitle = list.title
        let listID = list.id
        guard !trimmed.isEmpty, trimmed != previousTitle else { return }
        list.title = trimmed
        saveContext()
        registerUndoAction(named: "Rename List") { [weak self] in
            guard let self, let currentList = self.fetchList(id: listID) else { return }
            currentList.title = previousTitle
        }
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
        let createdTaskID = task.id
        registerUndoAction(named: "Add Task") { [weak self] in
            guard let self, let currentTask = self.fetchTask(id: createdTaskID) else { return }
            self.context.delete(currentTask)
        }
    }

    func toggleTask(_ task: TodoTask) {
        let previousCompleted = task.isCompleted
        let previousCompletedAt = task.completedAt
        let taskID = task.id
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        if task.isCompleted {
            settings.completionSound.play()
        }
        saveContext()
        registerUndoAction(named: task.isCompleted ? "Complete Task" : "Uncomplete Task") { [weak self] in
            guard let self, let currentTask = self.fetchTask(id: taskID) else { return }
            currentTask.isCompleted = previousCompleted
            currentTask.completedAt = previousCompletedAt
        }
    }

    func deleteTask(_ task: TodoTask) {
        let snapshot = TaskSnapshot(task: task)
        context.delete(task)
        saveContext()
        registerUndoAction(named: "Delete Task") { [weak self] in
            self?.restoreTask(from: snapshot)
        }
    }

    func renameTask(_ task: TodoTask, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTitle = task.title
        let taskID = task.id
        guard !trimmed.isEmpty, trimmed != previousTitle else { return }
        task.title = trimmed
        saveContext()
        registerUndoAction(named: "Edit Task") { [weak self] in
            self?.fetchTask(id: taskID)?.title = previousTitle
        }
    }

    func swapTaskPositions(_ first: TodoTask, _ second: TodoTask) {
        let firstOrder = first.sortOrder
        let secondOrder = second.sortOrder
        let firstID = first.id
        let secondID = second.id
        first.sortOrder = secondOrder
        second.sortOrder = firstOrder
        saveContext()
        registerUndoAction(named: "Reorder Task") { [weak self] in
            guard let self,
                  let currentFirst = self.fetchTask(id: firstID),
                  let currentSecond = self.fetchTask(id: secondID) else { return }
            currentFirst.sortOrder = firstOrder
            currentSecond.sortOrder = secondOrder
        }
    }

    func beginTaskDrag(_ task: TodoTask) {
        guard draggedTaskID == nil else { return }
        draggedTaskID = task.id
        taskDragSnapshot = fetchTasks().map {
            TaskPositionSnapshot(taskID: $0.id, listID: $0.list?.id, sortOrder: $0.sortOrder)
        }
        taskDragCleanup?.cancel()
        let cleanup = DispatchWorkItem { [weak self] in
            self?.endTaskDrag()
        }
        taskDragCleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: cleanup)
    }

    func updateTaskDropTarget(draggedTaskID: UUID, targetTask: TodoTask, targetList: TodoList) {
        taskDropTargetID = targetTask.id

        guard let draggedTask = fetchTask(id: draggedTaskID),
              draggedTask.list?.id == targetList.id,
              let sourceIndex = targetList.orderedTasks.firstIndex(where: { $0.id == draggedTaskID }),
              let targetIndex = targetList.orderedTasks.firstIndex(where: { $0.id == targetTask.id }) else {
            taskDropEdge = .top
            return
        }

        taskDropEdge = sourceIndex < targetIndex ? .bottom : .top
    }

    func clearTaskDropTarget(_ taskID: UUID) {
        guard taskDropTargetID == taskID else { return }
        taskDropTargetID = nil
    }

    func endTaskDrag() {
        taskDragCleanup?.cancel()
        taskDragCleanup = nil
        taskDropTargetID = nil
        guard let snapshot = taskDragSnapshot else {
            draggedTaskID = nil
            return
        }
        taskDragSnapshot = nil
        draggedTaskID = nil

        let currentPositions = Dictionary(uniqueKeysWithValues: fetchTasks().map {
            ($0.id, ($0.list?.id, $0.sortOrder))
        })
        let didMove = snapshot.contains { item in
            guard let current = currentPositions[item.taskID] else { return true }
            return current.0 != item.listID || current.1 != item.sortOrder
        }
        guard didMove else { return }

        registerUndoAction(named: "Move Task") { [weak self] in
            self?.restoreTaskPositions(snapshot)
        }
        saveContext()
    }

    func moveTask(id: UUID, to targetList: TodoList, before targetTask: TodoTask? = nil) {
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return }

        let sourceList = task.list
        let originalTargetOrder = targetList.orderedTasks
        let sourceIndex = originalTargetOrder.firstIndex(where: { $0.id == task.id })
        let targetIndex = targetTask.flatMap { target in
            originalTargetOrder.firstIndex(where: { $0.id == target.id })
        }
        let isMovingDownInSameList: Bool
        if sourceList?.id == targetList.id, let sourceIndex, let targetIndex {
            isMovingDownInSameList = sourceIndex < targetIndex
        } else {
            isMovingDownInSameList = false
        }
        if sourceList?.id != targetList.id {
            task.list = targetList
        }

        var ordered = targetList.orderedTasks.filter { $0.id != task.id }
        if let targetTask,
           let index = ordered.firstIndex(where: { $0.id == targetTask.id }) {
            let insertionIndex = min(index + (isMovingDownInSameList ? 1 : 0), ordered.count)
            ordered.insert(task, at: insertionIndex)
        } else {
            ordered.append(task)
        }
        for (index, item) in ordered.enumerated() {
            item.sortOrder = Double(index)
        }

        if let sourceList, sourceList.id != targetList.id {
            for (index, item) in sourceList.orderedTasks.enumerated() {
                item.sortOrder = Double(index)
            }
        }
        saveContext()
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
        isPerformingUndo = true
        action.perform()
        isPerformingUndo = false
        canUndo = !undoActions.isEmpty
        saveContext()
        return true
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

            if key == "z", modifiers == [.command], !quickAddIsKey, !isEditingText {
                return self.undoLastAction() ? nil : event
            }

            if (event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)),
               modifiers == [.command], notePanelIsKey, !event.isARepeat {
                self.sendKeyboardCommand(.requestListDeletion)
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

    private func registerUndoAction(named name: String, perform: @escaping () -> Void) {
        guard !isPerformingUndo else { return }
        undoActions.append(UndoAction(name: name, perform: perform))
        if undoActions.count > 50 {
            undoActions.removeFirst(undoActions.count - 50)
        }
        canUndo = true
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
