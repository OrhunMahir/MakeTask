import SwiftUI
import WidgetKit

@main
struct MakeTaskWidgets: WidgetBundle {
    var body: some Widget { MakeTaskListWidget() }
}

struct MakeTaskListWidget: Widget {
    static let kind = "MakeTaskListWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: TaskWidgetConfiguration.self, provider: TaskWidgetProvider()) { entry in
            TaskWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("MakeTask")
        .description("Keep a list close and complete tasks without leaving Notification Center.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TaskWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TaskWidgetEntry { .preview }

    func snapshot(for configuration: TaskWidgetConfiguration, in context: Context) async -> TaskWidgetEntry {
        context.isPreview ? .preview : load(configuration)
    }

    func timeline(for configuration: TaskWidgetConfiguration, in context: Context) async -> Timeline<TaskWidgetEntry> {
        Timeline(entries: [load(configuration)], policy: .after(Date().addingTimeInterval(900)))
    }

    private func load(_ configuration: TaskWidgetConfiguration) -> TaskWidgetEntry {
        do {
            let snapshot = try WidgetSnapshotStore.shared().read()
            return TaskWidgetEntry(date: .now, list: snapshot?.list(id: configuration.list?.id),
                                   showCompleted: configuration.showCompleted,
                                   message: snapshot == nil ? "Open MakeTask to load your lists." :
                                    configuration.list != nil ? "This list is no longer available. Edit this widget to choose another." :
                                    "Create your first list in MakeTask.")
        } catch {
            return TaskWidgetEntry(date: .now, list: nil, showCompleted: false,
                                   message: "Open MakeTask to refresh your widget.")
        }
    }
}

private struct TaskWidgetEntryView: View {
    let entry: TaskWidgetEntry
    @Environment(\.widgetFamily) private var family
    var body: some View { TaskWidgetView(entry: entry, family: family) }
}
