import AppKit
import Combine
import QuartzCore
import SwiftData
import SwiftUI

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    let list: TodoList

    private unowned let coordinator: WindowCoordinator
    private var pendingSave: DispatchWorkItem?
    private var appearanceSubscriptions: Set<AnyCancellable> = []
    private var isChangingCollapseState = false

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
        panel.isMovableByWindowBackground = false
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
        observeWindowAppearance(settings: settings)
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

    private func observeWindowAppearance(settings: AppSettings) {
        settings.$transparencyEnabled
            .combineLatest(settings.$noteOpacity)
            .sink { [weak panel = window] transparencyEnabled, opacity in
                guard let panel else { return }
                panel.alphaValue = transparencyEnabled ? CGFloat(opacity) : 1
                panel.invalidateShadow()
            }
            .store(in: &appearanceSubscriptions)
    }

    func setCollapsed(_ collapsed: Bool, animated: Bool, persist: Bool = true) {
        guard let panel = window, !isChangingCollapseState else { return }
        let shouldAnimate = animated
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let currentFrame = panel.frame
        let top = currentFrame.maxY

        if collapsed {
            if !list.isCollapsed && currentFrame.height > NoteWindowMetrics.headerHeight {
                list.windowHeight = currentFrame.height
                list.windowWidth = currentFrame.width
            }
            panel.styleMask.remove(.resizable)

            let collapsedFrame = NSRect(
                x: currentFrame.minX,
                y: top - NoteWindowMetrics.collapsedHeaderHeight,
                width: currentFrame.width,
                height: NoteWindowMetrics.collapsedHeaderHeight
            )

            if shouldAnimate {
                isChangingCollapseState = true
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(collapsedFrame, display: true)
                } completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.list.isCollapsed = true
                        self.isChangingCollapseState = false
                        self.rememberCurrentFrame()
                        if persist { self.coordinator.saveContext() }
                    }
                }
                return
            }

            list.isCollapsed = true
            panel.setFrame(collapsedFrame, display: true)
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
            if shouldAnimate {
                isChangingCollapseState = true
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(expandedFrame, display: true)
                } completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.isChangingCollapseState = false
                        self.rememberCurrentFrame()
                        if persist { self.coordinator.saveContext() }
                    }
                }
                return
            }
            panel.setFrame(expandedFrame, display: true)
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
        if !list.isCollapsed && !isChangingCollapseState {
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
