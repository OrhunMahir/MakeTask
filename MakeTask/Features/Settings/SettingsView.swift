import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: WindowCoordinator

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 560, height: 390)
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
