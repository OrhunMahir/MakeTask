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
                        settings.playCompletionSound()
                    } label: {
                        Label("Preview", systemImage: "speaker.wave.2")
                    }
                    .disabled(settings.completionSound == .none)
                }

                HStack(spacing: 12) {
                    Label("Sound volume", systemImage: volumeSymbol)
                        .frame(width: 132, alignment: .leading)

                    Slider(
                        value: $settings.completionSoundVolume,
                        in: 0...1,
                        step: 0.05
                    )

                    Text("\(Int((settings.completionSoundVolume * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
                .disabled(settings.completionSound == .none)
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

    private var volumeSymbol: String {
        switch settings.completionSoundVolume {
        case ...0:
            "speaker.slash"
        case ..<0.35:
            "speaker.wave.1"
        case ..<0.7:
            "speaker.wave.2"
        default:
            "speaker.wave.3"
        }
    }
}
