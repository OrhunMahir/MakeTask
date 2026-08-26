import SwiftUI

struct TaskDetailView: View {
    @Bindable var task: TodoTask

    @EnvironmentObject private var coordinator: WindowCoordinator
    @State private var notesSaveWorkItem: DispatchWorkItem?

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
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Due", isOn: hasDueDate)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5, weight: .medium))

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

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if task.notes.isEmpty {
                        Text("Add a note…")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 7)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $task.notes)
                        .font(.system(size: 12))
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

    private func scheduleNotesSave() {
        notesSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            coordinator.saveContext()
        }
        notesSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }
}
