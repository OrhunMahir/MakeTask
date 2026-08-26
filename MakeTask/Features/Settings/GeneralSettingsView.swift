import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    @Query(sort: \TodoList.sortOrder) private var lists: [TodoList]

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginService

    var body: some View {
        Form {
            Section {
                Toggle("Launch MakeTask at login", isOn: launchAtLoginBinding)
            } header: {
                Text("Startup")
            }

            Section {
                Picker("Default list", selection: $settings.defaultListID) {
                    Text("None").tag(UUID?.none)
                    ForEach(lists) { list in
                        Text(list.title).tag(Optional(list.id))
                    }
                }

                Toggle("Hide completed tasks", isOn: $settings.hideCompletedTasks)

                HStack {
                    Picker("Completion sound", selection: $settings.completionSound) {
                        ForEach(AppSettings.CompletionSound.allCases) { sound in
                            Text(sound.title).tag(sound)
                        }
                    }

                    Button {
                        settings.completionSound.play()
                    } label: {
                        Label("Preview", systemImage: "speaker.wave.2")
                    }
                    .disabled(settings.completionSound == .none)
                }
            } header: {
                Text("Tasks")
            }

            Section {
                Text("All lists, tasks, and window positions stay on this Mac. MakeTask has no account, analytics, or telemetry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Privacy")
            }
        }
        .formStyle(.grouped)
        .alert("Launch at Login", isPresented: launchErrorBinding) {
            Button("OK") {
                launchAtLogin.errorMessage = nil
            }
        } message: {
            Text(launchAtLogin.errorMessage ?? "Unknown error")
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    private var launchErrorBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.errorMessage != nil },
            set: { if !$0 { launchAtLogin.errorMessage = nil } }
        )
    }
}
