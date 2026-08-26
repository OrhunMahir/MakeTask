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
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    appDelegate.windowCoordinator.focusNewTaskInActiveNote()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New List") {
                    _ = appDelegate.windowCoordinator.createList()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandMenu("Note") {
                Button("Search Tasks") {
                    appDelegate.windowCoordinator.sendKeyboardCommand(.search, activatingNote: true)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Hide Current Note") {
                    appDelegate.windowCoordinator.hideActiveNote()
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Collapse or Expand Current Note") {
                    appDelegate.windowCoordinator.collapseActiveNote()
                }
                .keyboardShortcut("m", modifiers: .command)

                Button("Show or Hide All Notes") {
                    appDelegate.windowCoordinator.toggleAllNotesVisibility()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Divider()

                Button("Undo Last MakeTask Action") {
                    appDelegate.windowCoordinator.undoLastAction()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appDelegate.windowCoordinator.canUndo)

                Button("Redo Last MakeTask Action") {
                    appDelegate.windowCoordinator.redoLastAction()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!appDelegate.windowCoordinator.canRedo)

                Button("Delete Current Note…  ⌘⌫", role: .destructive) {
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
