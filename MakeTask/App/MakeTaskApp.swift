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
            Label("MakeTask", systemImage: "checklist")
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
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    appDelegate.windowCoordinator.focusNewTaskInActiveNote()
                }

                Button("New List") {
                    _ = appDelegate.windowCoordinator.createList()
                }
            }

            CommandMenu("Note") {
                Button("Search Tasks") {
                    appDelegate.windowCoordinator.sendKeyboardCommand(.search, activatingNote: true)
                }

                Button("Hide Current Note") {
                    appDelegate.windowCoordinator.hideActiveNote()
                }

                Button("Collapse or Expand Current Note") {
                    appDelegate.windowCoordinator.collapseActiveNote()
                }

                Button("Show or Hide All Notes") {
                    appDelegate.windowCoordinator.toggleAllNotesVisibility()
                }

                Divider()

                Button("Undo Last MakeTask Action") {
                    appDelegate.windowCoordinator.undoLastAction()
                }
                .disabled(!appDelegate.windowCoordinator.canUndo)

                Button("Redo Last MakeTask Action") {
                    appDelegate.windowCoordinator.redoLastAction()
                }
                .disabled(!appDelegate.windowCoordinator.canRedo)

                Button("Delete Current Note…", role: .destructive) {
                    appDelegate.windowCoordinator.sendKeyboardCommand(.requestListDeletion, activatingNote: true)
                }

                Divider()

                Button("Quick Add") {
                    appDelegate.windowCoordinator.presentQuickAdd()
                }
            }
        }
    }
}
