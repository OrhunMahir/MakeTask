import SwiftUI

@main
struct MakeTaskApp: App {
    @NSApplicationDelegateAdaptor(MakeTaskAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .modelContainer(appDelegate.modelContainer)
                .environmentObject(appDelegate.windowCoordinator)
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.launchAtLogin)
        } label: {
            MakeTaskStatusLabel()
                .environmentObject(appDelegate.windowCoordinator)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .modelContainer(appDelegate.modelContainer)
                .environmentObject(appDelegate.windowCoordinator)
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.launchAtLogin)
                .environmentObject(appDelegate.localBackup)
        }
        .commands {
            MakeTaskCommands(coordinator: appDelegate.windowCoordinator)
        }
    }
}
