import SwiftData
import SwiftUI

struct QuickAddView: View {
    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @State private var title = ""
    @State private var selectedListID: UUID?
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("Add Task")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(settings.quickAddShortcutDescription)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            if lists.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create your first list")
                        .foregroundStyle(.secondary)
                    Button("New List") {
                        let list = coordinator.createList()
                        selectedListID = list.id
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("What needs to be done?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .focused($isTitleFocused)
                    .onSubmit(submit)

                HStack {
                    Text("List:")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)

                    Picker("", selection: selectedListBinding) {
                        ForEach(lists) { list in
                            Text(list.title).tag(list.id)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: 170)

                    Spacer()

                    Text("↩ Add  ·  esc Close")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(20)
        .frame(width: 420, height: 190)
        .background {
            ZStack {
                VisualEffectView(material: .popover)
                Color(nsColor: .windowBackgroundColor).opacity(0.20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
        }
        .onAppear {
            selectedListID = preferredList()?.id
            DispatchQueue.main.async {
                isTitleFocused = true
            }
        }
        .onChange(of: lists.map(\.id)) { _, _ in
            if !lists.contains(where: { $0.id == selectedListID }) {
                selectedListID = preferredList()?.id
            }
            if !lists.isEmpty {
                isTitleFocused = true
            }
        }
        .onExitCommand {
            coordinator.dismissQuickAdd()
        }
    }

    private var selectedListBinding: Binding<UUID> {
        Binding(
            get: { selectedListID ?? lists.first?.id ?? UUID() },
            set: { selectedListID = $0 }
        )
    }

    private func preferredList() -> TodoList? {
        if let id = settings.lastQuickCaptureListID,
           let list = lists.first(where: { $0.id == id }) {
            return list
        }
        if let id = settings.defaultListID,
           let list = lists.first(where: { $0.id == id }) {
            return list
        }
        return lists.first
    }

    private func submit() {
        guard let list = lists.first(where: { $0.id == selectedListID }) ?? preferredList() else {
            return
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        coordinator.addTask(title: trimmed, to: list)
        settings.lastQuickCaptureListID = list.id
        coordinator.show(list)
        coordinator.dismissQuickAdd()
    }
}
