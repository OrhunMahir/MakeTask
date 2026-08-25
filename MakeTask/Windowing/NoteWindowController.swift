import AppKit
import SwiftData
import SwiftUI

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    let list: TodoList

    private unowned let coordinator: WindowCoordinator
    private var pendingSave: DispatchWorkItem?

    init(
        list: TodoList,
        frame: NSRect,
        modelContainer: ModelContainer,
        coordinator: WindowCoordinator,
        settings: AppSettings
    ) {
        self.list = list
        self.coordinator = coordinator

        let panel = FloatingNotePanel(
            contentRect: frame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        panel.delegate = self
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .utilityWindow
        panel.minSize = NSSize(
            width: NoteWindowMetrics.minimumWidth,
            height: NoteWindowMetrics.headerHeight
        )

        let rootView = NoteView(list: list)
            .modelContainer(modelContainer)
            .environmentObject(coordinator)
            .environmentObject(settings)

        panel.contentView = NSHostingView(rootView: rootView)
        applyWindowMode()

        if list.isCollapsed {
            setCollapsed(true, animated: false, persist: false)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func activateAndFocus() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func applyWindowMode() {
        guard let panel = window as? NSPanel else { return }

        switch list.windowMode {
        case .desktop:
            let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
            panel.level = NSWindow.Level(rawValue: desktopLevel)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        case .alwaysOnTop:
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .normal:
            panel.level = .normal
            panel.collectionBehavior = [.moveToActiveSpace]
        }
    }

    func setCollapsed(_ collapsed: Bool, animated: Bool, persist: Bool = true) {
        guard let panel = window else { return }
        let currentFrame = panel.frame
        let top = currentFrame.maxY

        if collapsed {
            if !list.isCollapsed && currentFrame.height > NoteWindowMetrics.headerHeight {
                list.windowHeight = currentFrame.height
                list.windowWidth = currentFrame.width
            }
            list.isCollapsed = true
            panel.styleMask.remove(.resizable)

            let collapsedFrame = NSRect(
                x: currentFrame.minX,
                y: top - NoteWindowMetrics.headerHeight,
                width: currentFrame.width,
                height: NoteWindowMetrics.headerHeight
            )
            panel.setFrame(collapsedFrame, display: true, animate: animated)
        } else {
            list.isCollapsed = false
            panel.styleMask.insert(.resizable)

            let expandedHeight = max(list.windowHeight, NoteWindowMetrics.headerHeight + 120)
            let expandedFrame = NSRect(
                x: currentFrame.minX,
                y: top - expandedHeight,
                width: max(currentFrame.width, NoteWindowMetrics.minimumWidth),
                height: expandedHeight
            )
            panel.setFrame(expandedFrame, display: true, animate: animated)
        }

        rememberCurrentFrame()
        if persist { coordinator.saveContext() }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        coordinator.noteDidBecomeActive(list)
    }

    func windowDidMove(_ notification: Notification) {
        rememberCurrentFrame()
        scheduleSave()
    }

    func windowDidResize(_ notification: Notification) {
        rememberCurrentFrame()
        scheduleSave()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        rememberCurrentFrame()
        pendingSave?.cancel()
        coordinator.saveContext()
    }

    private func rememberCurrentFrame() {
        guard let frame = window?.frame else { return }
        list.windowX = frame.minX
        list.windowTop = frame.maxY
        list.windowWidth = frame.width
        if !list.isCollapsed {
            list.windowHeight = frame.height
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.coordinator.saveContext()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}
