import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: WindowCoordinator
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView(selection: $settings.selectedSettingsTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(AppSettings.SettingsTab.general)

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(AppSettings.SettingsTab.appearance)

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(AppSettings.SettingsTab.shortcuts)

            BackupSettingsView()
                .tabItem {
                    Label("Backup", systemImage: "externaldrive")
                }
                .tag(AppSettings.SettingsTab.backup)

            GuideView()
                .tabItem {
                    Label("Guide", systemImage: "questionmark.circle")
                }
                .tag(AppSettings.SettingsTab.guide)
        }
        .frame(width: 640, height: 500)
        .alert("MakeTask", isPresented: coordinatorErrorBinding) {
            Button("OK") {
                coordinator.errorMessage = nil
            }
        } message: {
            Text(coordinator.errorMessage ?? "Unknown error")
        }
    }

    private var coordinatorErrorBinding: Binding<Bool> {
        Binding(
            get: { coordinator.errorMessage != nil },
            set: { if !$0 { coordinator.errorMessage = nil } }
        )
    }
}
