import SwiftData
import SwiftUI

struct GuideView: View {
    private struct ShortcutItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let keys: String
    }

    private struct InteractionItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var shortcuts: [ShortcutItem] {
        [
            ShortcutItem(
                icon: "bolt.fill",
                title: "Quick Add",
                detail: "Capture a task from any app",
                keys: settings.quickAddShortcutDescription
            ),
            ShortcutItem(
                icon: "plus.circle",
                title: "New Task",
                detail: "Focus task entry in the active note",
                keys: settings.shortcutDescription(for: .newTask)
            ),
            ShortcutItem(
                icon: "plus.rectangle.on.rectangle",
                title: "New List",
                detail: "Create and immediately name a note",
                keys: settings.shortcutDescription(for: .newList)
            ),
            ShortcutItem(
                icon: "eye.slash",
                title: "Hide Note",
                detail: "Remove the active note from the desktop",
                keys: settings.shortcutDescription(for: .hideCurrentNote)
            ),
            ShortcutItem(
                icon: "rectangle.compress.vertical",
                title: "Collapse Note",
                detail: "Keep only the active note's header",
                keys: settings.shortcutDescription(for: .collapseCurrentNote)
            ),
            ShortcutItem(
                icon: "eye",
                title: "Show/Hide All",
                detail: "Global recovery when every note is hidden",
                keys: settings.shortcutDescription(for: .toggleAllNotesVisibility)
            ),
            ShortcutItem(
                icon: "magnifyingglass",
                title: "Search Tasks",
                detail: "Filter tasks in the active note",
                keys: settings.shortcutDescription(for: .searchTasks)
            ),
            ShortcutItem(
                icon: "arrow.uturn.backward",
                title: "Undo Action",
                detail: "Undo the last task or list change",
                keys: settings.shortcutDescription(for: .undo)
            ),
            ShortcutItem(
                icon: "arrow.uturn.forward",
                title: "Redo Action",
                detail: "Reapply the last undone MakeTask change",
                keys: settings.shortcutDescription(for: .redo)
            ),
            ShortcutItem(
                icon: "trash",
                title: "Delete Note",
                detail: "Ask before deleting the active note",
                keys: settings.shortcutDescription(for: .deleteCurrentNote)
            ),
            ShortcutItem(
                icon: "arrow.up.arrow.down",
                title: "Select Task",
                detail: "Move the keyboard selection",
                keys: "\(settings.shortcutDescription(for: .selectPreviousTask))  \(settings.shortcutDescription(for: .selectNextTask))"
            ),
            ShortcutItem(
                icon: "checkmark.circle",
                title: "Complete Task",
                detail: "Toggle the selected task",
                keys: settings.shortcutDescription(for: .completeSelectedTask)
            ),
            ShortcutItem(
                icon: "pencil",
                title: "Edit Task",
                detail: "Edit the selected task inline",
                keys: settings.shortcutDescription(for: .editSelectedTask)
            ),
            ShortcutItem(
                icon: "trash",
                title: "Delete Selected Task",
                detail: "Delete the current keyboard selection",
                keys: settings.shortcutDescription(for: .deleteSelectedTask)
            ),
            ShortcutItem(
                icon: "arrow.up.arrow.down.circle",
                title: "Reorder Task",
                detail: "Move the selected task up or down",
                keys: "\(settings.shortcutDescription(for: .moveSelectedTaskUp))  \(settings.shortcutDescription(for: .moveSelectedTaskDown))"
            ),
            ShortcutItem(
                icon: "arrow.left.arrow.right",
                title: "Move Between Lists",
                detail: "Move the selected task to the adjacent list",
                keys: "\(settings.shortcutDescription(for: .moveTaskToPreviousList))  \(settings.shortcutDescription(for: .moveTaskToNextList))"
            ),
            ShortcutItem(
                icon: "text.cursor",
                title: "Rename Current List",
                detail: "Select the active list title for editing",
                keys: settings.shortcutDescription(for: .renameCurrentList)
            ),
            ShortcutItem(
                icon: "checkmark.circle.badge.questionmark",
                title: "Toggle Completed Tasks",
                detail: "Collapse or expand the Completed section",
                keys: settings.shortcutDescription(for: .toggleCompletedTasks)
            ),
            ShortcutItem(
                icon: "trash.slash",
                title: "Clear Completed Tasks",
                detail: "Confirm before removing completed tasks",
                keys: settings.shortcutDescription(for: .clearCompletedTasks)
            ),
            ShortcutItem(
                icon: "square.stack",
                title: "Switch List",
                detail: "Activate lists one through nine",
                keys: "\(settings.shortcutDescription(for: .switchToList1))…\(settings.shortcutDescription(for: .switchToList9))"
            ),
            ShortcutItem(
                icon: "gearshape",
                title: "Settings",
                detail: "Open MakeTask preferences",
                keys: "⌘,"
            ),
            ShortcutItem(
                icon: "xmark",
                title: "Cancel",
                detail: "Close Quick Add or cancel text entry",
                keys: "esc"
            )
        ]
    }

    private let interactions = [
        InteractionItem(
            icon: "pencil",
            title: "Click a list title",
            detail: "Rename the list inline. New lists select their name automatically."
        ),
        InteractionItem(
            icon: "cursorarrow.motionlines",
            title: "Drag empty header space",
            detail: "Move a note without accidentally moving it while dragging a task."
        ),
        InteractionItem(
            icon: "rectangle.compress.vertical",
            title: "Double-click empty header space",
            detail: "Collapse or expand the note while keeping its top edge anchored."
        ),
        InteractionItem(
            icon: "hand.point.up.left",
            title: "Hold and drag a task",
            detail: "The lifted card follows the pointer while a live gap shows its exact position in this or another note."
        ),
        InteractionItem(
            icon: "checkmark.circle",
            title: "Click a task's circle",
            detail: "Complete or uncomplete the task, move it softly between sections, and play your selected sound at the volume set in General settings."
        ),
        InteractionItem(
            icon: "note.text",
            title: "Click a task title",
            detail: "Open notes, due date/time, priority, and subtasks. Double-click a subtask title to rename it."
        ),
        InteractionItem(
            icon: "chevron.down",
            title: "Click the Completed header",
            detail: "Collapse or expand completed tasks. Each list remembers this state."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                guideHeader
                quickActions
                shortcutSection
                behaviorSection
                interactionSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var guideHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text("MakeTask Guide")
                    .font(.system(size: 22, weight: .bold))
                Text("Apple Stickies for todos — everything important in one place.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(lists.lazy.filter { !$0.isHidden }.count)/\(lists.count) visible")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    private var quickActions: some View {
        guideSection(title: "Quick Actions", subtitle: "These perform the same commands as the menu bar.") {
            HStack(spacing: 8) {
                Button {
                    coordinator.presentQuickAdd()
                } label: {
                    Label("Quick Add", systemImage: "bolt.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    _ = coordinator.createList()
                } label: {
                    Label("New List", systemImage: "plus")
                }

                Button {
                    coordinator.showAll()
                } label: {
                    Label("Show All", systemImage: "eye")
                }
                .disabled(lists.isEmpty)

                Button {
                    coordinator.hideAll()
                } label: {
                    Label("Hide All", systemImage: "eye.slash")
                }
                .disabled(lists.isEmpty)
            }
            .controlSize(.regular)
        }
    }

    private var shortcutSection: some View {
        guideSection(
            title: "Keyboard Shortcuts",
            subtitle: "Quick Add and Show/Hide All are global; note commands act on MakeTask's active note."
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(shortcuts) { shortcut in
                    HStack(spacing: 10) {
                        Image(systemName: shortcut.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortcut.title)
                                .font(.system(size: 12.5, weight: .semibold))
                            Text(shortcut.detail)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 5)
                        ShortcutKeyBadge(keys: shortcut.keys)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 57, alignment: .leading)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var behaviorSection: some View {
        guideSection(title: "Hide Is Not Collapse", subtitle: "MakeTask keeps these as two independent, persisted states.") {
            HStack(alignment: .top, spacing: 10) {
                behaviorCard(
                    icon: "rectangle.compress.vertical",
                    title: "Collapse",
                    detail: "Only the header remains on the desktop. Double-click the empty header or press \(settings.shortcutDescription(for: .collapseCurrentNote)) to expand it again.",
                    tint: .orange
                )
                behaviorCard(
                    icon: "eye.slash",
                    title: "Hide",
                    detail: "The note disappears completely. Restore it from the menu bar, Quick Add's Show Note button, or \(settings.shortcutDescription(for: .toggleAllNotesVisibility)).",
                    tint: .blue
                )
                behaviorCard(
                    icon: "macwindow",
                    title: "Normal Window",
                    detail: "This is the default. Stay on Desktop and Always on Top remain optional per-note modes.",
                    tint: .purple
                )
            }
        }
    }

    private var interactionSection: some View {
        guideSection(title: "Mouse & Trackpad", subtitle: "Small gestures keep note windows minimal.") {
            VStack(spacing: 0) {
                ForEach(Array(interactions.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: item.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 23)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 12.5, weight: .semibold))
                            Text(item.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 9)

                    if index < interactions.count - 1 {
                        Divider().padding(.leading, 34)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func guideSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func behaviorCard(
        icon: String,
        title: String,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 13, weight: .bold))
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(tint.opacity(0.16), lineWidth: 0.75)
        }
    }
}

private struct ShortcutKeyBadge: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }
}
