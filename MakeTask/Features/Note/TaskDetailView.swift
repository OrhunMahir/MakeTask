import SwiftUI

struct TaskDetailView: View {
    @Bindable var task: TodoTask

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var notesSaveWorkItem: DispatchWorkItem?
    @State private var newSubtaskTitle = ""
    @FocusState private var isNewSubtaskFocused: Bool

    private var noteTint: Color {
        task.list?.noteColor.tint ?? .accentColor
    }

    private var completedSubtaskCount: Int {
        task.subtasks.filter(\.isCompleted).count
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { task.dueDate != nil },
            set: { enabled in
                let defaultDueDate = Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: Date()
                ) ?? Date().addingTimeInterval(86_400)
                coordinator.setDueDate(
                    enabled ? (task.dueDate ?? defaultDueDate) : nil,
                    for: task
                )
            }
        )
    }

    private var dueDate: Binding<Date> {
        Binding(
            get: { task.dueDate ?? Date() },
            set: { value in
                coordinator.setDueDate(value, for: task)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            priorityMenu

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Due", isOn: hasDueDate)
                    .toggleStyle(.checkbox)
                    .font(settings.font(size: 11.5, weight: .medium))

                if task.dueDate != nil {
                    DatePicker(
                        "",
                        selection: dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            subtaskSection

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(settings.font(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if task.notes.isEmpty {
                        Text("Add a note…")
                            .font(settings.font(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 7)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $task.notes)
                        .font(settings.font(size: 12))
                        .scrollContentBackground(.hidden)
                        .padding(2)
                        .onChange(of: task.notes) { _, _ in
                            scheduleNotesSave()
                        }
                }
                .frame(minHeight: 58, maxHeight: 86)
                .background(
                    Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
                }
            }
        }
        .padding(.leading, 36)
        .padding(.trailing, 12)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .onDisappear {
            notesSaveWorkItem?.cancel()
            coordinator.saveContext()
        }
    }

    private var priorityMenu: some View {
        HStack {
            Text("Priority")
                .font(settings.font(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                ForEach(TaskPriority.allCases) { priority in
                    Button {
                        coordinator.setPriority(priority, for: task)
                    } label: {
                        Label(
                            priority.title,
                            systemImage: priority == task.priorityLevel
                                ? "checkmark"
                                : priority.symbolName
                        )
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: task.priorityLevel.symbolName)
                    Text(task.priorityLevel.title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(settings.font(size: 10.5, weight: .medium))
                .foregroundStyle(task.priorityLevel.tint)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(
                    task.priorityLevel.tint.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var subtaskSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("Subtasks")
                    .font(settings.font(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                if !task.subtasks.isEmpty {
                    Text("\(completedSubtaskCount)/\(task.subtasks.count)")
                        .font(settings.font(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            if !task.subtasks.isEmpty {
                VStack(spacing: 1) {
                    ForEach(task.orderedSubtasks) { subtask in
                        SubtaskRowView(subtask: subtask, tint: noteTint)
                    }
                }
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.18),
                    value: task.orderedSubtasks.map { "\($0.id)-\($0.isCompleted)" }
                )
            }

            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Add subtask…", text: $newSubtaskTitle)
                    .textFieldStyle(.plain)
                    .font(settings.font(size: 11.5))
                    .focused($isNewSubtaskFocused)
                    .onSubmit(addSubtask)
                    .onExitCommand {
                        newSubtaskTitle = ""
                        isNewSubtaskFocused = false
                    }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
        }
    }

    private func scheduleNotesSave() {
        notesSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            coordinator.saveContext()
        }
        notesSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            coordinator.addSubtask(title: trimmed, to: task)
        }
        newSubtaskTitle = ""
        isNewSubtaskFocused = true
    }
}

private struct SubtaskRowView: View {
    @Bindable var subtask: TodoSubtask
    let tint: Color

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var titleDraft = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    coordinator.toggleSubtask(subtask)
                }
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(subtask.isCompleted ? tint : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(subtask.isCompleted ? "Mark subtask incomplete" : "Complete subtask")

            if isEditing {
                TextField("Subtask title", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(settings.font(size: 11.5))
                    .focused($isTitleFocused)
                    .onSubmit(commitEditing)
                    .onExitCommand(perform: cancelEditing)
            } else {
                Text(subtask.title)
                    .font(settings.font(size: 11.5))
                    .strikethrough(subtask.isCompleted, color: .secondary)
                    .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: beginEditing)
            }

            if isHovering && !isEditing {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                        coordinator.deleteSubtask(subtask)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete subtask")
            }
        }
        .padding(.horizontal, 7)
        .frame(minHeight: 26)
        .background(
            Color.primary.opacity(isHovering ? 0.045 : 0),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit Subtask") {
                beginEditing()
            }
            Button(subtask.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                coordinator.toggleSubtask(subtask)
            }
            Divider()
            Button("Delete Subtask", role: .destructive) {
                coordinator.deleteSubtask(subtask)
            }
        }
        .onChange(of: isTitleFocused) { _, focused in
            if !focused && isEditing {
                commitEditing()
            }
        }
    }

    private func beginEditing() {
        titleDraft = subtask.title
        isEditing = true
        DispatchQueue.main.async {
            isTitleFocused = true
        }
    }

    private func commitEditing() {
        guard isEditing else { return }
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            cancelEditing()
            return
        }
        coordinator.renameSubtask(subtask, to: trimmed)
        isEditing = false
        isTitleFocused = false
    }

    private func cancelEditing() {
        titleDraft = subtask.title
        isEditing = false
        isTitleFocused = false
    }
}
