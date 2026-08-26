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
            Label("New Task", systemImage: "plus.circle")
        }
        .keyboardShortcut("n", modifiers: .command)

        Button {
            _ = coordinator.createList()
        } label: {
            Label("New List", systemImage: "plus.rectangle.on.rectangle")
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button {
            coordinator.collapseActiveNote()
        } label: {
            Label("Collapse/Expand Current Note", systemImage: "rectangle.compress.vertical")
        }
        .keyboardShortcut("m", modifiers: .command)

        Button {
            coordinator.hideActiveNote()
        } label: {
            Label("Hide Current Note", systemImage: "eye.slash")
        }
        .keyboardShortcut("w", modifiers: .command)

        if !lists.isEmpty {
            Button {
                coordinator.toggleAllNotesVisibility()
            } label: {
                Label(
                    lists.allSatisfy { !$0.isHidden } ? "Hide All Notes" : "Show All Notes",
                    systemImage: lists.allSatisfy { !$0.isHidden } ? "eye.slash" : "eye"
                )
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
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
