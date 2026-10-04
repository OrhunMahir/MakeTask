import AppKit
import Carbon
import SwiftData
import SwiftUI

@MainActor
final class MakeTaskAppDelegate: NSObject, NSApplicationDelegate {
    private var uiTestWindow: NSWindow?
    private var hasStarted = false
    private var pendingAppIconReveal = false

    let modelContainer: ModelContainer
    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginService
    lazy var windowCoordinator = WindowCoordinator(
        modelContainer: modelContainer,
        settings: settings,
        launchAtLogin: launchAtLogin,
        saveChanges: simulatedSaveFailure
    )
    lazy var localBackup = LocalBackupService(coordinator: windowCoordinator)

    private var simulatedSaveFailure: ((ModelContext) throws -> Void)? {
        #if DEBUG
        if AppRuntime.isRunningUITests,
           ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_SAVE_FAILURE"] == "1" {
            return { _ in throw CocoaError(.fileWriteNoPermission) }
        }
        #endif
        return nil
    }

    override init() {
        do {
            modelContainer = try PersistenceController.makeContainer(
                inMemory: AppRuntime.isRunningTests
            )
        } catch {
            fatalError("Could not create MakeTask's local data store: \(error)")
        }
        settings = AppSettings(defaults: AppRuntime.makeSettingsDefaults())
        launchAtLogin = LaunchAtLoginService()
        super.init()
        if !AppRuntime.isRunningTests {
            WidgetActionDispatcher.coordinator = windowCoordinator
            windowCoordinator.onWidgetRefresh = { [weak self] in
                guard let self else { return }
                try WidgetBridge.publish(context: self.modelContainer.mainContext)
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !AppRuntime.isRunningUnitTests else { return }
        NSApp.setActivationPolicy(.regular)
        // Handle explicit launch/reopen events, not activation (which also occurs
        // for widgets and keyboard shortcuts). SwiftUI owns the app delegate proxy.
        for eventID in [kAEOpenApplication, kAEReopenApplication] {
            NSAppleEventManager.shared().setEventHandler(
                self, andSelector: #selector(handleAppOpenEvent(_:withReplyEvent:)),
                forEventClass: AEEventClass(kCoreEventClass), andEventID: AEEventID(eventID)
            )
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.applyAppearance()

        if AppRuntime.isRunningUITests {
            DispatchQueue.main.async { [weak self] in
                self?.startUITestSession()
            }
            return
        }

        guard !AppRuntime.isRunningUnitTests else { return }
        windowCoordinator.start(registerGlobalShortcuts: AppRuntime.supportsGlobalShortcuts())
        windowCoordinator.refreshWidgets()
        finishStarting()
    }

    @objc private func handleAppOpenEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard AppRuntime.shouldRevealNotes(for: event) else { return }
        // UI tests seed their own initial workspace; Dock reopens still use the real path.
        if AppRuntime.isRunningUITests && event.eventID == AEEventID(kAEOpenApplication)
            && ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_APP_OPEN"] != "1" { return }
        guard hasStarted else { pendingAppIconReveal = true; return }
        windowCoordinator.revealNotesFromAppIcon()
    }

    private func finishStarting() {
        hasStarted = true
        if pendingAppIconReveal {
            pendingAppIconReveal = false
            windowCoordinator.revealNotesFromAppIcon()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let route = WidgetRoute(url: url) else { continue }
            windowCoordinator.handleWidgetRoute(route)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Commit active field edits before checking the final persistent save.
        sender.keyWindow?.makeFirstResponder(nil)
        guard !windowCoordinator.prepareForTermination() else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "MakeTask could not save your changes"
        alert.informativeText = "Your latest changes have not been saved. Cancel to keep MakeTask open and retry saving. If you quit without saving, those changes will be lost."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit Without Saving")
        sender.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        if !AppRuntime.isRunningUnitTests {
            for eventID in [kAEOpenApplication, kAEReopenApplication] {
                NSAppleEventManager.shared().removeEventHandler(
                    forEventClass: AEEventClass(kCoreEventClass), andEventID: AEEventID(eventID)
                )
            }
        }
        windowCoordinator.stop()
        windowCoordinator.saveContext()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startUITestSession() {
        defer { finishStarting() }
        settings.completionSound = .none
        windowCoordinator.start(registerGlobalShortcuts: false)

        if ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_WELCOME"] == "1" {
            if ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_APP_OPEN"] != "1" {
                windowCoordinator.presentWelcomeIfNeeded()
            }
            return
        }

        let context = modelContainer.mainContext
        let testAppOpen = ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_APP_OPEN"] == "1"
        let list = TodoList(title: "UI Test List", isHidden: testAppOpen)
        context.insert(list)
        context.insert(TodoTask(title: "Alpha Task", sortOrder: 0, list: list))
        context.insert(TodoTask(title: "Beta Task", sortOrder: 1, list: list))
        settings.defaultListID = list.id
        settings.lastQuickCaptureListID = list.id
        windowCoordinator.noteDidBecomeActive(list)
        windowCoordinator.saveContext()

        if ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_NATIVE_NOTES"] == "1" {
            if ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_DOCK"] == "1" {
                let hidden = TodoList(title: "Dock Hidden List", sortOrder: 1, isHidden: true)
                context.insert(hidden)
                context.insert(TodoTask(title: "Dock Hidden Task", list: hidden))
                windowCoordinator.saveContext()
            }
            switch ProcessInfo.processInfo.environment["MAKETASK_UI_TEST_WIDGET_ROUTE"] {
            case "task":
                let task = list.orderedTasks[0]
                task.isCompleted = true
                task.completedAt = .now
                list.isCollapsed = true
                list.isCompletedSectionCollapsed = true
                settings.hideCompletedTasks = true
                windowCoordinator.saveContext()
                windowCoordinator.handleWidgetRoute(.task(task.id))
            case "add":
                let target = TodoList(title: "Widget Target", isHidden: true)
                context.insert(target)
                windowCoordinator.saveContext()
                windowCoordinator.handleWidgetRoute(.add(target.id))
            default:
                if !testAppOpen { windowCoordinator.showAndActivate(list) }
            }
            return
        }

        let rootView = UITestHostView()
            .modelContainer(modelContainer)
            .environmentObject(windowCoordinator)
            .environmentObject(settings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("note.ui-test-host")
        window.title = "MakeTask UI Tests"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        uiTestWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKey()
    }
}
