import SwiftUI

/// Observe history availability so native menu items refresh after every action.
struct MakeTaskCommands: Commands {
    @ObservedObject var coordinator: WindowCoordinator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") {
                coordinator.focusNewTaskInActiveNote()
            }

            Button("New List") {
                _ = coordinator.createList()
            }
        }

        CommandMenu("Note") {
            Button("Search Tasks") {
                coordinator.sendKeyboardCommand(.search, activatingNote: true)
            }

            Button("Hide Current Note") {
                coordinator.hideActiveNote()
            }

            Button("Collapse or Expand Current Note") {
                coordinator.collapseActiveNote()
            }

            Button("Show or Hide All Notes") {
                coordinator.toggleAllNotesVisibility()
            }

            Divider()

            Button("Undo Last MakeTask Action") {
                coordinator.undoLastAction()
            }
            .disabled(!coordinator.canUndo)

            Button("Redo Last MakeTask Action") {
                coordinator.redoLastAction()
            }
            .disabled(!coordinator.canRedo)

            Button("Delete Current Note…", role: .destructive) {
                coordinator.sendKeyboardCommand(.requestListDeletion, activatingNote: true)
            }

            Divider()

            Button("Quick Add") {
                coordinator.presentQuickAdd()
            }
        }
    }
}
