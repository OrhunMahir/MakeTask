import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var coordinator: WindowCoordinator

    @State private var recordingAction: AppShortcutAction?
    @State private var validationMessages: [AppShortcutAction: String] = [:]
    @State private var eventMonitor: Any?

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Click a shortcut, then press the new key combination.")
                            .font(.callout)
                        Text("Esc cancels recording. Global shortcuts require at least one modifier key.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Reset All to Defaults") {
                        resetAllShortcuts()
                    }
                }
            }

            ForEach(AppShortcutSection.allCases) { section in
                Section {
                    ForEach(actions(in: section)) { action in
                        shortcutRow(for: action)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                        Text(section.detail)
                            .font(.caption)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: installEventMonitor)
        .onDisappear {
            cancelRecording()
            removeEventMonitor()
        }
    }

    private func actions(in section: AppShortcutSection) -> [AppShortcutAction] {
        AppShortcutAction.allCases.filter { $0.section == section }
    }

    private func shortcutRow(for action: AppShortcutAction) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: action.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(action.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = validationMessages[action] {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)

            Button {
                startRecording(action)
            } label: {
                Text(recordingAction == action
                     ? "Press keys…"
                     : settings.shortcutDescription(for: action))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 92)
            }
            .buttonStyle(.bordered)
            .tint(recordingAction == action ? .accentColor : nil)
            .help("Record a new shortcut")

            Button {
                resetShortcut(action)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .disabled(settings.shortcut(for: action) == action.defaultShortcut)
            .help("Reset this shortcut")
        }
        .padding(.vertical, 3)
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard recordingAction != nil else { return event }
            record(event)
            return nil
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func startRecording(_ action: AppShortcutAction) {
        validationMessages[action] = nil
        recordingAction = action
        coordinator.beginShortcutRecording()
    }

    private func record(_ event: NSEvent) {
        guard let action = recordingAction, !event.isARepeat else { return }

        if Int(event.keyCode) == kVK_Escape {
            cancelRecording()
            return
        }

        let shortcut = AppShortcut(event: event)
        if action.isGlobal && shortcut.modifiers.isEmpty {
            validationMessages[action] = "Global shortcuts need Command, Shift, Option, or Control."
            cancelRecording(keepingMessage: true)
            return
        }

        if let systemConflictDescription = shortcut.systemConflictDescription {
            validationMessages[action] = systemConflictDescription + "."
            cancelRecording(keepingMessage: true)
            return
        }

        let conflicts = settings.conflictingActions(for: shortcut, excluding: action)
        if !conflicts.isEmpty {
            let names = conflicts.map(\.title).joined(separator: ", ")
            validationMessages[action] = "Already used by \(names)."
            cancelRecording(keepingMessage: true)
            return
        }

        let previousShortcut = settings.shortcut(for: action)
        settings.setShortcut(shortcut, for: action)
        recordingAction = nil
        let registrationError = coordinator.endShortcutRecording()

        if action.isGlobal, let registrationError {
            settings.setShortcut(previousShortcut, for: action)
            _ = coordinator.reloadGlobalShortcuts()
            validationMessages[action] = registrationError
        } else {
            validationMessages[action] = nil
        }
    }

    private func resetShortcut(_ action: AppShortcutAction) {
        cancelRecording()
        let defaultShortcut = action.defaultShortcut
        let conflicts = settings.conflictingActions(for: defaultShortcut, excluding: action)
        guard conflicts.isEmpty else {
            validationMessages[action] = "Default is currently used by \(conflicts.map(\.title).joined(separator: ", "))."
            return
        }

        let previousShortcut = settings.shortcut(for: action)
        settings.resetShortcut(action)
        validationMessages[action] = nil
        if action.isGlobal {
            if let registrationError = coordinator.reloadGlobalShortcuts() {
                settings.setShortcut(previousShortcut, for: action)
                _ = coordinator.reloadGlobalShortcuts()
                validationMessages[action] = registrationError
            }
        }
    }

    private func resetAllShortcuts() {
        cancelRecording()
        settings.resetAllShortcuts()
        validationMessages.removeAll()
        _ = coordinator.reloadGlobalShortcuts()
    }

    private func cancelRecording(keepingMessage: Bool = false) {
        guard recordingAction != nil else { return }
        if !keepingMessage, let recordingAction {
            validationMessages[recordingAction] = nil
        }
        recordingAction = nil
        _ = coordinator.endShortcutRecording()
    }
}
