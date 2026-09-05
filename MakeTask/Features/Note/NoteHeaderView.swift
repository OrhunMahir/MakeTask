import AppKit
import SwiftUI

struct NoteHeaderView: View {
    @Bindable var list: TodoList
    @Binding var isConfirmingDelete: Bool

    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @State private var isRenaming = false
    @State private var titleDraft = ""
    @FocusState private var isTitleFocused: Bool

    private var completedCount: Int {
        list.tasks.lazy.filter(\.isCompleted).count
    }

    private var headerHeight: CGFloat {
        list.isCollapsed
            ? NoteWindowMetrics.collapsedHeaderHeight
            : NoteWindowMetrics.headerHeight
    }

    private var titleSize: CGFloat {
        list.isCollapsed ? 14 : 13.5
    }

    var body: some View {
        HStack(spacing: 8) {
            if list.isCollapsed {
                Image(systemName: completedCount == list.tasks.count && !list.tasks.isEmpty
                    ? "checkmark.circle"
                    : "circle.dashed"
                )
                .font(settings.font(size: 15, weight: .semibold))
                .foregroundStyle(list.noteColor.tint)
                .frame(width: 18)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(list.noteColor.tint)
                    .frame(width: 4, height: 18)
            }

            if isRenaming {
                TextField("List name", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(settings.font(size: titleSize, weight: list.isCollapsed ? .bold : .semibold))
                    .accessibilityIdentifier("note.list-name-field")
                    .focused($isTitleFocused)
                    .onSubmit(commitRename)
                    .onExitCommand(perform: cancelRename)
            } else {
                Text(list.title)
                    .font(settings.font(size: titleSize, weight: list.isCollapsed ? .bold : .semibold))
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
                if list.isCollapsed {
                    Circle()
                        .fill(list.noteColor.tint.opacity(0.62))
                        .frame(width: 6, height: 6)
                }

                Text("\(completedCount)/\(list.tasks.count)")
                    .font(settings.font(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, list.isCollapsed ? 7 : 0)
                    .frame(height: list.isCollapsed ? 20 : nil)
                    .background {
                        if list.isCollapsed {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                        }
                    }
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
                    .font(settings.font(size: 12, weight: .semibold))
                    .frame(width: 20, height: 22)
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
        .frame(height: headerHeight)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: list.isCollapsed
        )
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
