import AppKit
import SwiftData
import SwiftUI

@MainActor
final class MakeTaskAppDelegate: NSObject, NSApplicationDelegate {
    private var uiTestWindow: NSWindow?

    let modelContainer: ModelContainer
    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginService
    lazy var windowCoordinator = WindowCoordinator(
        modelContainer: modelContainer,
        settings: settings,
        launchAtLogin: launchAtLogin
    )
    lazy var localBackup = LocalBackupService(coordinator: windowCoordinator)

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
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if AppRuntime.isRunningUITests {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AppRuntime.isRunningUITests {
            NSApp.setActivationPolicy(.accessory)
        }
        settings.applyAppearance()

        if AppRuntime.isRunningUITests {
            DispatchQueue.main.async { [weak self] in
                self?.startUITestSession()
            }
            return
        }

        guard !AppRuntime.isRunningUnitTests else { return }
        windowCoordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowCoordinator.stop()
        windowCoordinator.saveContext()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startUITestSession() {
        settings.completionSound = .none
        windowCoordinator.start(registerGlobalShortcuts: false)

        let context = modelContainer.mainContext
        let list = TodoList(title: "UI Test List")
        context.insert(list)
        context.insert(TodoTask(title: "Alpha Task", sortOrder: 0, list: list))
        context.insert(TodoTask(title: "Beta Task", sortOrder: 1, list: list))
        settings.defaultListID = list.id
        settings.lastQuickCaptureListID = list.id
        windowCoordinator.noteDidBecomeActive(list)
        windowCoordinator.saveContext()

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
