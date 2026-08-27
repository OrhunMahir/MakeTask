import SwiftData
import SwiftUI

struct MenuBarView: View {
    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]

    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Button {
            coordinator.presentQuickAdd()
        } label: {
            Label("Quick Add — \(settings.quickAddShortcutDescription)", systemImage: "bolt.fill")
        }

        Divider()

        if lists.isEmpty {
            Text("Create your first list")
                .foregroundStyle(.secondary)
        } else {
            ForEach(lists) { list in
                Button {
                    coordinator.toggleVisibility(of: list)
                } label: {
                    Label(
                        list.isHidden ? "\(list.title) — Hidden" : "\(list.title) — Visible",
                        systemImage: list.isHidden ? "eye.slash" : "eye"
                    )
                }
            }
        }

        Divider()

        Button {
            coordinator.focusNewTaskInActiveNote()
        } label: {
            Label(
                "New Task — \(settings.shortcutDescription(for: .newTask))",
                systemImage: "plus.circle"
            )
        }

        Button {
            coordinator.sendKeyboardCommand(.search, activatingNote: true)
        } label: {
            Label(
                "Search Tasks — \(settings.shortcutDescription(for: .searchTasks))",
                systemImage: "magnifyingglass"
            )
        }

        Button {
            _ = coordinator.createList()
        } label: {
            Label(
                "New List — \(settings.shortcutDescription(for: .newList))",
                systemImage: "plus.rectangle.on.rectangle"
            )
        }

        Button {
            coordinator.collapseActiveNote()
        } label: {
            Label(
                "Collapse/Expand Current Note — \(settings.shortcutDescription(for: .collapseCurrentNote))",
                systemImage: "rectangle.compress.vertical"
            )
        }

        Button {
            coordinator.hideActiveNote()
        } label: {
            Label(
                "Hide Current Note — \(settings.shortcutDescription(for: .hideCurrentNote))",
                systemImage: "eye.slash"
            )
        }

        if !lists.isEmpty {
            Button {
                coordinator.toggleAllNotesVisibility()
            } label: {
                Label(
                    "\(lists.allSatisfy { !$0.isHidden } ? "Hide All Notes" : "Show All Notes") — \(settings.shortcutDescription(for: .toggleAllNotesVisibility))",
                    systemImage: lists.allSatisfy { !$0.isHidden } ? "eye.slash" : "eye"
                )
            }

            Menu {
                ForEach(Array(lists.prefix(9).enumerated()), id: \.element.id) { index, list in
                    Button {
                        coordinator.activateList(at: index)
                    } label: {
                        Label(
                            "\(list.title)    \(settings.shortcutDescription(for: AppShortcutAction.listSwitchActions[index]))",
                            systemImage: list.isHidden ? "eye.slash" : "rectangle.on.rectangle"
                        )
                    }
                }
            } label: {
                Label("Switch List", systemImage: "square.stack")
            }
        }

        Button {
            coordinator.undoLastAction()
        } label: {
            Label(
                "Undo Last Action — \(settings.shortcutDescription(for: .undo))",
                systemImage: "arrow.uturn.backward"
            )
        }
        .disabled(!coordinator.canUndo)

        Button {
            coordinator.redoLastAction()
        } label: {
            Label(
                "Redo Last Action — \(settings.shortcutDescription(for: .redo))",
                systemImage: "arrow.uturn.forward"
            )
        }
        .disabled(!coordinator.canRedo)

        Button(role: .destructive) {
            coordinator.sendKeyboardCommand(.requestListDeletion, activatingNote: true)
        } label: {
            Label(
                "Delete Current Note… — \(settings.shortcutDescription(for: .deleteCurrentNote))",
                systemImage: "trash"
            )
        }

        Divider()

        Button {
            settings.selectedSettingsTab = .guide
            openSettings()
        } label: {
            Label("MakeTask Guide…", systemImage: "questionmark.circle")
        }

        Button {
            settings.selectedSettingsTab = .general
            openSettings()
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit MakeTask") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
