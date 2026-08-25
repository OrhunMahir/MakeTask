import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppSettings.AppearanceMode.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Use transparency and blur", isOn: $settings.transparencyEnabled)

                HStack {
                    Text("Note opacity")
                    Slider(value: $settings.noteOpacity, in: 0.70...1.0, step: 0.02)
                    Text(settings.noteOpacity.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
                .disabled(!settings.transparencyEnabled)
            } header: {
                Text("Desktop Notes")
            }
        }
        .formStyle(.grouped)
    }
}
