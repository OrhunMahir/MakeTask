import SwiftUI

struct NewTaskField: View {
    let list: TodoList
    @Binding var title: String
    var isFocused: FocusState<Bool>.Binding

    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("New task…", text: $title)
                .textFieldStyle(.plain)
                .font(settings.font(size: 13.5))
                .accessibilityIdentifier("note.new-task-field")
                .accessibilityLabel("New task")
                .focused(isFocused)
                .onSubmit(addTask)
                .onExitCommand {
                    title = ""
                    isFocused.wrappedValue = false
                }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color.primary.opacity(0.035))
    }

    private func addTask() {
        coordinator.addTask(title: title, to: list)
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = ""
        }
    }
}
