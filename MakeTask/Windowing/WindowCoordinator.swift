import AppKit
import Combine
import SwiftData

@MainActor
final class WindowCoordinator: ObservableObject {
    let modelContainer: ModelContainer
    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginService

    @Published private(set) var activeListID: UUID?
    @Published var focusNewTaskListID: UUID?
    @Published var errorMessage: String?

    private let context: ModelContext
    private var noteWindows: [UUID: NoteWindowController] = [:]
    private var quickAddWindow: QuickAddWindowController?
    private var hotKeyService: GlobalHotKeyService?

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
        do {
            let service = try GlobalHotKeyService()
            service.onPressed = { [weak self] in
                self?.presentQuickAdd()
            }
            hotKeyService = service
            reloadGlobalShortcut()
        } catch {
            errorMessage = error.localizedDescription
        }

        restoreVisibleNotes()
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
        return list
    }

    func deleteList(_ list: TodoList) {
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
        guard !trimmed.isEmpty else { return }
        list.title = trimmed
        saveContext()
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

    func hide(_ list: TodoList) {
        list.isHidden = true
        noteWindows[list.id]?.hide()
        saveContext()
    }

    func toggleVisibility(of list: TodoList) {
        list.isHidden ? show(list) : hide(list)
    }

    func showAll() {
        fetchLists().forEach(show)
    }

    func hideAll() {
        fetchLists().forEach(hide)
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

    func addTask(title: String, to list: TodoList) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let order = (list.tasks.map(\.sortOrder).max() ?? -1) + 1
        let task = TodoTask(title: trimmed, sortOrder: order, list: list)
        context.insert(task)
        saveContext()
    }

    func toggleTask(_ task: TodoTask) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        saveContext()
    }

    func deleteTask(_ task: TodoTask) {
        context.delete(task)
        saveContext()
    }

    func moveTask(id: UUID, to targetList: TodoList, before targetTask: TodoTask? = nil) {
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return }

        let sourceList = task.list
        if sourceList?.id != targetList.id {
            task.list = targetList
        }

        var ordered = targetList.orderedTasks.filter { $0.id != task.id }
        if let targetTask,
           let index = ordered.firstIndex(where: { $0.id == targetTask.id }) {
            ordered.insert(task, at: index)
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
            hotKeyService?.unregister()
            errorMessage = "The global shortcut needs at least one modifier key."
            return
        }
        do {
            try hotKeyService?.register(
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

    private func activeList() -> TodoList? {
        guard let activeListID else { return nil }
        return fetchLists().first { $0.id == activeListID }
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
