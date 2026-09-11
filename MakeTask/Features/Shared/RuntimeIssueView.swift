import SwiftUI

struct RuntimeIssueIndicator: View {
    @EnvironmentObject private var coordinator: WindowCoordinator
    @State private var isShowingDetails = false

    var body: some View {
        if coordinator.hasRuntimeIssues {
            Button {
                isShowingDetails.toggle()
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 20, height: 22)
            }
            .buttonStyle(.plain)
            .help("MakeTask needs attention")
            .accessibilityLabel("MakeTask needs attention")
            .accessibilityIdentifier("runtime.issue-indicator")
            .popover(isPresented: $isShowingDetails) {
                RuntimeIssueDetails()
            }
        }
    }
}

private struct RuntimeIssueDetails: View {
    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = coordinator.persistenceError {
                Text("Changes haven’t been saved")
                    .font(.headline)
                    .accessibilityIdentifier("runtime.save-warning")
                Text("Keep MakeTask open and retry saving your latest changes.")
                DisclosureGroup("Details") { Text(message).textSelection(.enabled) }
                    .foregroundStyle(.secondary)
                Button("Retry Saving") { coordinator.saveContext() }
                    .accessibilityIdentifier("runtime.retry-save")
            }
            if !coordinator.globalShortcutErrors.isEmpty {
                if coordinator.persistenceError != nil { Divider() }
                Text("Global shortcut unavailable").font(.headline)
                ForEach([AppShortcutAction.quickAdd, .toggleAllNotesVisibility], id: \.self) { action in
                    if let message = coordinator.globalShortcutErrors[action] {
                        Text(action.title).fontWeight(.medium)
                        Text(message).foregroundStyle(.secondary)
                    }
                }
                Text("You can still use these actions from the menu bar.")
                HStack {
                    Button("Retry Shortcuts") { _ = coordinator.reloadGlobalShortcuts() }
                    Button("Shortcut Settings…") {
                        settings.selectedSettingsTab = .shortcuts
                        openSettings()
                    }
                }
            }
            if !coordinator.hasRuntimeIssues {
                Label("All issues resolved", systemImage: "checkmark.circle")
            }
        }
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct MakeTaskStatusLabel: View {
    @EnvironmentObject private var coordinator: WindowCoordinator

    var body: some View {
        Label("MakeTask", systemImage: coordinator.hasRuntimeIssues
              ? "exclamationmark.triangle.fill" : "checklist")
            .help(coordinator.hasRuntimeIssues ? "MakeTask needs attention" : "MakeTask")
    }
}
