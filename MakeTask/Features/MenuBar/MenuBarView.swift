import SwiftData
import SwiftUI

struct MenuBarView: View {
    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]

    @EnvironmentObject private var coordinator: WindowCoordinator

    var body: some View {
        Button {
            coordinator.presentQuickAdd()
        } label: {
            Label("Quick Add", systemImage: "bolt.fill")
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
                        list.title,
                        systemImage: list.isHidden ? "circle" : "checkmark.circle.fill"
                    )
                }
            }
        }

        Divider()

        Button {
            _ = coordinator.createList()
        } label: {
            Label("New List", systemImage: "plus.rectangle.on.rectangle")
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        if !lists.isEmpty {
            Button("Show All") {
                coordinator.showAll()
            }
            Button("Hide All") {
                coordinator.hideAll()
            }
        }

        Divider()

        SettingsLink {
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
