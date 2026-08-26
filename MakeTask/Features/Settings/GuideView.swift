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
                keys: "⌘N"
            ),
            ShortcutItem(
                icon: "plus.rectangle.on.rectangle",
                title: "New List",
                detail: "Create and immediately name a note",
                keys: "⇧⌘N"
            ),
            ShortcutItem(
                icon: "eye.slash",
                title: "Hide Note",
                detail: "Remove the active note from the desktop",
                keys: "⌘W"
            ),
            ShortcutItem(
                icon: "rectangle.compress.vertical",
                title: "Collapse Note",
                detail: "Keep only the active note's header",
                keys: "⌘M"
            ),
            ShortcutItem(
                icon: "eye",
                title: "Show/Hide All",
                detail: "Global recovery when every note is hidden",
                keys: "⇧⌘H"
            ),
            ShortcutItem(
                icon: "magnifyingglass",
                title: "Search Tasks",
                detail: "Filter tasks in the active note",
                keys: "⌘F"
            ),
            ShortcutItem(
                icon: "arrow.uturn.backward",
                title: "Undo Action",
                detail: "Undo the last task or list change",
                keys: "⌘Z"
            ),
            ShortcutItem(
                icon: "trash",
                title: "Delete Note",
                detail: "Ask before deleting the active note",
                keys: "⌘⌫"
            ),
            ShortcutItem(
                icon: "arrow.up.arrow.down",
                title: "Select Task",
                detail: "Move the keyboard selection",
                keys: "↑  ↓"
            ),
            ShortcutItem(
                icon: "checkmark.circle",
                title: "Complete Task",
                detail: "Toggle the selected task",
                keys: "Space"
            ),
            ShortcutItem(
                icon: "pencil",
                title: "Edit Task",
                detail: "Edit the selected task inline",
                keys: "Return"
            ),
            ShortcutItem(
                icon: "arrow.up.arrow.down.circle",
                title: "Reorder Task",
                detail: "Move the selected task up or down",
                keys: "⌥↑  ⌥↓"
            ),
            ShortcutItem(
                icon: "square.stack",
                title: "Switch List",
                detail: "Activate lists one through nine",
                keys: "⌘1…9"
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
            detail: "Move over another row to reorder immediately, then drop it there or in another note."
        ),
        InteractionItem(
            icon: "checkmark.circle",
            title: "Click a task or its circle",
            detail: "Complete or uncomplete the task."
        )
    ]

    private let nextShortcutIdeas = [
        ("Delete selected task", "⌫"),
        ("Rename current list", "⌘L"),
        ("Move task between lists", "⌃⌘←  ⌃⌘→"),
        ("Toggle completed tasks", "⇧⌘C"),
        ("Clear completed tasks", "⌥⌘⌫")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                guideHeader
                quickActions
                shortcutSection
                behaviorSection
                interactionSection
                nextIdeasSection
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
                    detail: "Only the header remains on the desktop. Double-click the empty header or press ⌘M to expand it again.",
                    tint: .orange
                )
                behaviorCard(
                    icon: "eye.slash",
                    title: "Hide",
                    detail: "The note disappears completely. Restore it from the menu bar, Quick Add's Show Note button, or ⇧⌘H.",
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

    private var nextIdeasSection: some View {
        guideSection(
            title: "Good Next Shortcut Ideas",
            subtitle: "Ideas only — the shortcuts above are active now; these are possible later additions."
        ) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(nextShortcutIdeas, id: \.0) { idea in
                    HStack {
                        Text(idea.0)
                            .font(.system(size: 11.5, weight: .medium))
                        Spacer()
                        ShortcutKeyBadge(keys: idea.1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                }
            }
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
