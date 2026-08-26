import SwiftData
import SwiftUI

struct QuickAddView: View {
    private enum FocusField: Hashable {
        case taskTitle
        case listName
    }

    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @State private var title = ""
    @State private var selectedListID: UUID?
    @State private var isCreatingList = false
    @State private var newListName = ""
    @FocusState private var focusedField: FocusField?

    private var isListCreationMode: Bool {
        isCreatingList || lists.isEmpty
    }

    private var selectedList: TodoList? {
        lists.first(where: { $0.id == selectedListID }) ?? preferredList()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: isListCreationMode ? "plus.rectangle.on.rectangle" : "bolt.fill")
                    .foregroundStyle(isListCreationMode ? Color.accentColor : Color.yellow)
                Text(isListCreationMode ? "New List" : "Add Task")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(settings.quickAddShortcutDescription)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            if isListCreationMode {
                listCreationForm
            } else {
                taskCreationForm
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
            isCreatingList = lists.isEmpty
            focusAppropriateField()
        }
        .onChange(of: lists.map(\.id)) { _, _ in
            if !lists.contains(where: { $0.id == selectedListID }) {
                selectedListID = preferredList()?.id
            }
            if lists.isEmpty {
                isCreatingList = true
            }
            focusAppropriateField()
        }
        .onExitCommand {
            if isCreatingList && !lists.isEmpty {
                cancelListCreation()
            } else {
                coordinator.dismissQuickAdd()
            }
        }
    }

    private var taskCreationForm: some View {
        Group {
            TextField("What needs to be done?", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                .focused($focusedField, equals: .taskTitle)
                .onSubmit(submitTask)

            HStack(spacing: 7) {
                Text("List:")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)

                Picker("", selection: selectedListBinding) {
                    ForEach(lists) { list in
                        Label(
                            list.title,
                            systemImage: list.isHidden ? "eye.slash" : "circle.fill"
                        )
                        .tag(list.id)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: 155)

                Button {
                    beginListCreation()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create a new list")

                if let selectedList, selectedList.isHidden {
                    Button {
                        coordinator.showAndActivate(selectedList)
                    } label: {
                        Label("Show Note", systemImage: "eye")
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11.5))
                }

                Spacer(minLength: 4)

                Text("↩ Add  ·  esc Close")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var listCreationForm: some View {
        Group {
            TextField("List name", text: $newListName)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                .focused($focusedField, equals: .listName)
                .onSubmit(createNamedList)

            HStack {
                if lists.isEmpty {
                    Text("Create your first list")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                } else {
                    Button("Cancel") {
                        cancelListCreation()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text("↩ Create  ·  esc Cancel")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)

                Button("Create") {
                    createNamedList()
                }
                .disabled(trimmedListName.isEmpty)
            }
        }
    }

    private var selectedListBinding: Binding<UUID> {
        Binding(
            get: { selectedListID ?? lists.first?.id ?? UUID() },
            set: { selectedListID = $0 }
        )
    }

    private var trimmedListName: String {
        newListName.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func submitTask() {
        guard let list = selectedList else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        coordinator.addTask(title: trimmed, to: list)
        settings.lastQuickCaptureListID = list.id
        coordinator.showAndActivate(list)
        coordinator.dismissQuickAdd()
    }

    private func beginListCreation() {
        newListName = ""
        isCreatingList = true
        DispatchQueue.main.async {
            focusedField = .listName
        }
    }

    private func cancelListCreation() {
        isCreatingList = false
        newListName = ""
        DispatchQueue.main.async {
            focusedField = .taskTitle
        }
    }

    private func createNamedList() {
        guard !trimmedListName.isEmpty else { return }
        let list = coordinator.createList(title: trimmedListName)
        settings.lastQuickCaptureListID = list.id
        coordinator.dismissQuickAdd()
    }

    private func focusAppropriateField() {
        DispatchQueue.main.async {
            focusedField = isListCreationMode ? .listName : .taskTitle
        }
    }
}
