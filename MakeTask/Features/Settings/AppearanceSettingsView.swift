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
                Picker("Font", selection: $settings.typography) {
                    ForEach(AppSettings.Typography.allCases) { typography in
                        Text(typography.title).tag(typography)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MakeTask typography")
                            .font(settings.font(size: 15, weight: .semibold))
                        Text("Plan clearly. Finish calmly.")
                            .font(settings.font(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

                Text("The selected font is used in desktop notes and Quick Add. Native menus keep the system font for macOS consistency.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Typography")
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
