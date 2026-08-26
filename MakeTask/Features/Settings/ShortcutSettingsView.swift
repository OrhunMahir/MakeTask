import Carbon.HIToolbox
import SwiftUI

struct ShortcutSettingsView: View {
    private struct KeyOption: Identifiable {
        let code: UInt32
        let title: String
        var id: UInt32 { code }
    }

    private let keyOptions = [
        KeyOption(code: UInt32(kVK_Space), title: "Space"),
        KeyOption(code: UInt32(kVK_Return), title: "Return"),
        KeyOption(code: UInt32(kVK_ANSI_A), title: "A"),
        KeyOption(code: UInt32(kVK_ANSI_N), title: "N"),
        KeyOption(code: UInt32(kVK_ANSI_T), title: "T")
    ]

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var coordinator: WindowCoordinator

    var body: some View {
        Form {
            Section {
                LabeledContent("Current shortcut") {
                    Text(settings.quickAddShortcutDescription)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                }

                Picker("Key", selection: $settings.quickAddKeyCode) {
                    ForEach(keyOptions) { option in
                        Text(option.title).tag(option.code)
                    }
                }

                HStack(spacing: 18) {
                    Toggle("⌘ Command", isOn: $settings.quickAddUsesCommand)
                    Toggle("⇧ Shift", isOn: $settings.quickAddUsesShift)
                    Toggle("⌥ Option", isOn: $settings.quickAddUsesOption)
                    Toggle("⌃ Control", isOn: $settings.quickAddUsesControl)
                }
                .toggleStyle(.checkbox)

                if noModifiersSelected {
                    Label("Choose at least one modifier to avoid replacing normal typing.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Global Quick Add")
            }

            Section {
                shortcutRow("New Task", shortcut: "⌘N")
                shortcutRow("New List", shortcut: "⇧⌘N")
                shortcutRow("Hide Current Note", shortcut: "⌘W")
                shortcutRow("Collapse Current Note", shortcut: "⌘M")
                shortcutRow("Show/Hide All Notes", shortcut: "⇧⌘H")
            } header: {
                Text("App Shortcuts")
            }
        }
        .formStyle(.grouped)
        .onChange(of: shortcutSignature) { _, _ in
            guard !noModifiersSelected else { return }
            coordinator.reloadGlobalShortcut()
        }
    }

    private var shortcutSignature: String {
        "\(settings.quickAddKeyCode)-\(settings.quickAddUsesCommand)-\(settings.quickAddUsesShift)-\(settings.quickAddUsesOption)-\(settings.quickAddUsesControl)"
    }

    private var noModifiersSelected: Bool {
        !settings.quickAddUsesCommand
            && !settings.quickAddUsesShift
            && !settings.quickAddUsesOption
            && !settings.quickAddUsesControl
    }

    private func shortcutRow(_ title: String, shortcut: String) -> some View {
        LabeledContent(title) {
            Text(shortcut)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .rounded))
        }
    }
}
