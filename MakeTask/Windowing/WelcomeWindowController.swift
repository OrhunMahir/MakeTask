import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(coordinator: WindowCoordinator, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        super.init(window: window)
        window.title = "Welcome to MakeTask"
        window.identifier = NSUserInterfaceItemIdentifier("maketask.welcome")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: WelcomeView().environmentObject(coordinator))
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { onClose() }
}

private struct WelcomeView: View {
    @EnvironmentObject private var coordinator: WindowCoordinator
    @State private var listName = "My Tasks"
    @State private var showsPrivacy = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable().frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A little room for your tasks.").font(.title2.bold())
                    Text("Welcome to MakeTask").foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("Find MakeTask in your menu bar, even when your notes are hidden.", systemImage: "menubar.rectangle")
                Label("Keep a separate desktop note for each list.", systemImage: "rectangle.on.rectangle")
                Label("Your tasks stay on this Mac. No account needed.", systemImage: "lock")
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name your first list").font(.headline)
                TextField("List name", text: $listName)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .accessibilityIdentifier("welcome.list-name")
                    .onSubmit(createList)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Privacy Policy") { showsPrivacy = true }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("welcome.privacy-policy")
                Spacer()
                Button("Later") { coordinator.dismissWelcome() }
                    .accessibilityIdentifier("welcome.later")
                Button("Create List", action: createList)
                    .keyboardShortcut(.defaultAction)
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("welcome.create-list")
            }
        }
        .padding(28)
        .frame(width: 520, height: 460)
        .onAppear { nameFocused = true }
        .sheet(isPresented: $showsPrivacy) { PrivacyPolicyView() }
    }

    private func createList() {
        _ = coordinator.createListFromWelcome(title: listName)
    }
}
