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
                Toggle("Transparent note windows", isOn: $settings.transparencyEnabled)

                HStack {
                    Text("Window opacity")
                    Slider(value: $settings.noteOpacity, in: 0.45...1.0, step: 0.05)
                    Text(settings.noteOpacity.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
                .disabled(!settings.transparencyEnabled)

                Text("Transparency applies immediately to every open note window. Text and controls fade together with the window.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Desktop Notes")
            }
        }
        .formStyle(.grouped)
    }
}
