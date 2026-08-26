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

    override init() {
        do {
            modelContainer = try PersistenceController.makeContainer()
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
