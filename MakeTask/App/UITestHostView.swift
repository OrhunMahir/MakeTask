import SwiftData
import SwiftUI

struct UITestHostView: View {
    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]

    @EnvironmentObject private var coordinator: WindowCoordinator

    private var activeList: TodoList? {
        if let activeListID = coordinator.activeListID,
           let list = lists.first(where: { $0.id == activeListID }) {
            return list
        }
        return lists.first
    }

    var body: some View {
        Group {
            if let list = activeList {
                if list.isHidden {
                    Text("Note hidden")
                        .accessibilityIdentifier("note.hidden")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    NoteView(list: list)
                }
            } else {
                ProgressView()
                    .accessibilityIdentifier("note.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 320, minHeight: 360)
    }
}
