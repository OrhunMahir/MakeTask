import SwiftUI
import WidgetKit

struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let list: WidgetListSnapshot?
    let showCompleted: Bool
    let message: String

    static var preview: Self {
        Self(date: .now, list: WidgetListSnapshot(id: UUID(), title: "Today", color: "purple", tasks: [
            WidgetTaskSnapshot(id: UUID(), title: "Plan the week ahead", isCompleted: false, priority: 0, dueDate: nil),
            WidgetTaskSnapshot(id: UUID(), title: "Send the project proposal", isCompleted: false, priority: 3, dueDate: nil),
            WidgetTaskSnapshot(id: UUID(), title: "Make time for a walk", isCompleted: true, priority: 0, dueDate: nil)
        ]), showCompleted: true, message: "")
    }
}

struct TaskWidgetView: View {
    let entry: TaskWidgetEntry
    let family: WidgetFamily

    private var capacity: Int { family == .systemLarge ? 9 : 3 }
    private var tint: Color {
        switch entry.list?.color {
        case "yellow": .yellow
        case "orange": .orange
        case "red": .red
        case "pink": .pink
        case "purple": .purple
        case "indigo": .indigo
        case "blue": .blue
        case "teal": .teal
        case "green": .green
        default: .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "checklist").foregroundStyle(tint)
                Link(entry.list?.title ?? "MakeTask", destination: entry.list.map { WidgetRoute.list($0.id).url } ?? WidgetRoute.home.url)
                    .font(.headline).lineLimit(1)
                Spacer(minLength: 0)
                if let list = entry.list {
                    Text("\(list.remainingCount)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .accessibilityLabel("\(list.remainingCount) remaining tasks")
                }
            }
            if let list = entry.list {
                let tasks = list.visibleTasks(showCompleted: entry.showCompleted)
                if tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(list.tasks.isEmpty ? "A fresh start" : "All done!").font(.headline)
                        Text(list.tasks.isEmpty ? "Add your first task." : "Enjoy a little breathing room.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxHeight: .infinity, alignment: .center)
                } else {
                    ForEach(Array(tasks.prefix(capacity))) { task in
                        HStack(spacing: 8) {
                            Button(intent: SetWidgetTaskCompletion(taskID: task.id, completed: !task.isCompleted)) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18)).foregroundStyle(task.isCompleted ? tint : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(task.isCompleted ? "Uncomplete" : "Complete") \(task.title)")
                            Link(destination: WidgetRoute.task(task.id).url) {
                                Text(task.title).font(.subheadline).lineLimit(1)
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if task.priority > 0 && family != .systemSmall {
                                Image(systemName: "flag.fill").font(.caption2)
                                    .foregroundStyle(task.priority == 3 ? .red : task.priority == 2 ? .orange : .blue)
                                    .accessibilityLabel("\(task.priority == 3 ? "High" : task.priority == 2 ? "Medium" : "Low") priority")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Link(destination: WidgetRoute.add(list.id).url) {
                        Label("New task", systemImage: "plus").font(.caption.weight(.semibold))
                    }
                    Spacer(minLength: 0)
                    if tasks.count > capacity {
                        Link("+\(tasks.count - capacity) more", destination: WidgetRoute.list(list.id).url)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(entry.message).font(.caption).foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .center)
                Link("Open MakeTask", destination: WidgetRoute.home.url).font(.caption.weight(.semibold))
            }
        }
        .widgetURL(entry.list.map { WidgetRoute.list($0.id).url } ?? WidgetRoute.home.url)
        .privacySensitive()
    }
}
