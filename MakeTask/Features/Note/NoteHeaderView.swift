import SwiftUI

struct NoteHeaderView: View {
    @Bindable var list: TodoList
    @Binding var isRenaming: Bool
    @Binding var isConfirmingDelete: Bool

    @EnvironmentObject private var coordinator: WindowCoordinator

    private var completedCount: Int {
        list.tasks.lazy.filter(\.isCompleted).count
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(list.noteColor.tint)
                .frame(width: 4, height: 18)

            Text(list.title)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 8)

            if !list.tasks.isEmpty {
                Text("\(completedCount)/\(list.tasks.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Menu {
                Button("Rename") {
                    isRenaming = true
                }

                Menu("Change Color") {
                    ForEach(NoteColor.allCases) { color in
                        Button {
                            coordinator.setColor(color, for: list)
                        } label: {
                            if list.noteColor == color {
                                Label(color.title, systemImage: "checkmark")
                            } else {
                                Text(color.title)
                            }
                        }
                    }
                }

                Menu("Window Behavior") {
                    ForEach(WindowMode.allCases) { mode in
                        Button {
                            coordinator.setWindowMode(mode, for: list)
                        } label: {
                            if list.windowMode == mode {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                }

                Divider()

                Button(list.isCollapsed ? "Expand" : "Collapse") {
                    coordinator.toggleCollapse(list)
                }

                Button("Hide Note") {
                    coordinator.hide(list)
                }

                Divider()

                Button("Delete List", role: .destructive) {
                    isConfirmingDelete = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("List options")
        }
        .padding(.horizontal, 12)
        .frame(height: NoteWindowMetrics.headerHeight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            coordinator.toggleCollapse(list)
        }
    }
}
