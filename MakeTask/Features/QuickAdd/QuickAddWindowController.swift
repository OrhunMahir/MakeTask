import AppKit
import SwiftData
import SwiftUI

@MainActor
final class QuickAddWindowController: NSWindowController, NSWindowDelegate {
    private unowned let coordinator: WindowCoordinator

    init(
        modelContainer: ModelContainer,
        coordinator: WindowCoordinator,
        settings: AppSettings
    ) {
        self.coordinator = coordinator

        let styleMask: NSWindow.StyleMask = AppRuntime.isRunningUITests
            ? [.titled, .fullSizeContentView]
            : [.borderless]
        let panel = FloatingNotePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 190),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)

        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        if AppRuntime.isRunningUITests {
            panel.title = "Quick Add"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.setAccessibilityIdentifier("quick-add.window")
        }

        let rootView = QuickAddView()
            .modelContainer(modelContainer)
            .environmentObject(coordinator)
            .environmentObject(settings)
        panel.contentView = NSHostingView(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        positionOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        coordinator.dismissQuickAdd()
    }

    private func positionOnActiveScreen() {
        guard let panel = window else { return }
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        ))
    }
}
