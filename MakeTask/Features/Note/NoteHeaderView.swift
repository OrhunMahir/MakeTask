import AppKit
import SwiftUI

struct NoteHeaderView: View {
    @Bindable var list: TodoList
    @Binding var isConfirmingDelete: Bool

    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @State private var isRenaming = false
    @State private var titleDraft = ""
    @FocusState private var isTitleFocused: Bool

    private var completedCount: Int {
        list.tasks.lazy.filter(\.isCompleted).count
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(list.noteColor.tint)
                .frame(width: 4, height: 18)

            if isRenaming {
                TextField("List name", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .semibold))
                    .accessibilityIdentifier("note.list-name-field")
                    .focused($isTitleFocused)
                    .onSubmit(commitRename)
                    .onExitCommand(perform: cancelRename)
            } else {
                Text(list.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("note.title.\(list.id.uuidString)")
                    .contentShape(Rectangle())
                    .onTapGesture(perform: beginRename)
                    .help("Click to rename")
            }

            WindowDragArea {
                guard !isRenaming else { return }
                coordinator.toggleCollapse(list)
            }
            .frame(minWidth: 12, maxWidth: .infinity, maxHeight: .infinity)
            .help("Drag to move · Double-click to collapse")

            if !list.tasks.isEmpty {
                Text("\(completedCount)/\(list.tasks.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Menu {
                Button("Rename") {
                    beginRename()
                }

                Menu("Change Color") {
                    ForEach(NoteColor.allCases) { color in
                        Button {
                            coordinator.setColor(color, for: list)
                        } label: {
                            Label {
                                Text(color.title)
                            } icon: {
                                Image(nsImage: color.menuSwatchImage(isSelected: list.noteColor == color))
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

                Button {
                    settings.selectedSettingsTab = .guide
                    openSettings()
                } label: {
                    Label("Guide & Shortcuts…", systemImage: "questionmark.circle")
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
            .accessibilityIdentifier("note.options")
            .accessibilityLabel("List options")
        }
        .padding(.horizontal, 12)
        .frame(height: NoteWindowMetrics.headerHeight)
        .onReceive(coordinator.$renameListID) { listID in
            guard listID == list.id else { return }
            beginRename()
        }
        .onChange(of: isTitleFocused) { _, isFocused in
            if !isFocused && isRenaming {
                commitRename()
            }
        }
    }

    private func beginRename() {
        titleDraft = list.title
        isRenaming = true
        DispatchQueue.main.async {
            isTitleFocused = true
            DispatchQueue.main.async {
                (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
            }
        }
    }

    private func commitRename() {
        guard isRenaming else { return }
        isRenaming = false
        isTitleFocused = false
        coordinator.renameList(list, to: titleDraft)
    }

    private func cancelRename() {
        isRenaming = false
        isTitleFocused = false
        titleDraft = list.title
    }
}
