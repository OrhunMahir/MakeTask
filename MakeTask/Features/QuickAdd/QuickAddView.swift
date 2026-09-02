import SwiftData
import SwiftUI

enum QuickAddWindowMetrics {
    static let width: CGFloat = 560
    static let height: CGFloat = 250
    static let cornerRadius: CGFloat = 22
}

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
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(isListCreationMode ? "New List" : "Add Task")
                    .font(settings.font(size: 19, weight: .bold))
                Spacer()
                Text(settings.quickAddShortcutDescription)
                    .font(settings.font(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            if isListCreationMode {
                listCreationForm
            } else {
                taskCreationForm
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 26)
        .frame(width: QuickAddWindowMetrics.width, height: QuickAddWindowMetrics.height)
        .background {
            ZStack {
                VisualEffectView(material: .popover)
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.10),
                        Color(nsColor: .windowBackgroundColor).opacity(0.16),
                        Color.orange.opacity(0.045)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: QuickAddWindowMetrics.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: QuickAddWindowMetrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
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
            VStack(alignment: .leading, spacing: 7) {
                TextField("What needs to be done?", text: $title)
                    .textFieldStyle(.plain)
                    .font(settings.font(size: 18, weight: .medium))
                    .accessibilityIdentifier("quick-add.task-field")
                    .accessibilityLabel("Quick add task")
                    .focused($focusedField, equals: .taskTitle)
                    .onSubmit(submitTask)

                Rectangle()
                    .fill((selectedList?.noteColor.tint ?? Color.accentColor).opacity(0.48))
                    .frame(height: 1)
            }
            .padding(.horizontal, 4)
            .frame(height: 54)

            HStack(spacing: 10) {
                Picker("", selection: selectedListBinding) {
                    ForEach(lists) { list in
                        HStack {
                            Image(systemName: list.isHidden ? "eye.slash" : "circle.fill")
                                .foregroundStyle(list.noteColor.tint)
                            Text(list.title)
                        }
                        .tag(list.id)
                    }
                }
                .labelsHidden()
                .controlSize(.regular)
                .font(settings.font(size: 13, weight: .medium))
                .frame(width: 175)
                .tint(selectedList?.noteColor.tint ?? .accentColor)

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
                    .font(settings.font(size: 11.5, weight: .medium))
                }

                Spacer()

                Button("Cancel") {
                    coordinator.dismissQuickAdd()
                }
                .buttonStyle(.plain)
                .font(settings.font(size: 13, weight: .medium))

                Button("Add Task") {
                    submitTask()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(settings.font(size: 13, weight: .semibold))
                .tint(selectedList?.noteColor.tint ?? .accentColor)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var listCreationForm: some View {
        Group {
            TextField("List name", text: $newListName)
                .textFieldStyle(.plain)
                .font(settings.font(size: 18, weight: .medium))
                .accessibilityIdentifier("quick-add.list-name-field")
                .accessibilityLabel("New list name")
                .padding(.horizontal, 4)
                .frame(height: 54)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.48))
                        .frame(height: 1)
                }
                .focused($focusedField, equals: .listName)
                .onSubmit(createNamedList)

            HStack {
                if lists.isEmpty {
                    Text("Create your first list")
                        .font(settings.font(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Button("Cancel") {
                        cancelListCreation()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button("Create") {
                    createNamedList()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(settings.font(size: 13, weight: .semibold))
                .disabled(trimmedListName.isEmpty)
                .keyboardShortcut(.defaultAction)
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
