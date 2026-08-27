import AppKit
import SwiftData

@MainActor
final class MakeTaskAppDelegate: NSObject, NSApplicationDelegate {
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
        settings = AppSettings()
        launchAtLogin = LaunchAtLoginService()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settings.applyAppearance()
        guard !AppRuntime.isRunningTests else { return }
        windowCoordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowCoordinator.stop()
        windowCoordinator.saveContext()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
