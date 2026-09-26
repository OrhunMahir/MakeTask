import AppKit
import Combine
import SwiftData
import SwiftUI

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    let list: TodoList

    private unowned let coordinator: WindowCoordinator
    private unowned let settings: AppSettings
    private var pendingSave: DispatchWorkItem?
    private var appearanceSubscriptions: Set<AnyCancellable> = []
    private var isChangingCollapseState = false
    private var isFittingToScreen = false
    private let visibleScreenFrames: @MainActor () -> [NSRect]
    private var pendingScreenFrames: [NSRect]?
    let presentation: NoteCollapsePresentation
    private let animationDriver: any NoteCollapseAnimationDriving
    private let reduceMotion: () -> Bool
    private var requestedCollapsed: Bool
    private var queuedRequest: (collapsed: Bool, animated: Bool, persist: Bool)?

    init(
        list: TodoList,
        frame: NSRect,
        modelContainer: ModelContainer,
        coordinator: WindowCoordinator,
        settings: AppSettings,
        animationDriver: (any NoteCollapseAnimationDriving)? = nil,
        reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
        visibleScreenFrames: @escaping @MainActor () -> [NSRect] = { NoteScreenGeometry.currentVisibleFrames }
    ) {
        self.list = list
        self.coordinator = coordinator
        self.settings = settings
        self.presentation = NoteCollapsePresentation(collapsed: list.isCollapsed)
        self.requestedCollapsed = list.isCollapsed
        self.animationDriver = animationDriver ?? NoteCollapseAnimationDriver()
        self.reduceMotion = reduceMotion
        self.visibleScreenFrames = visibleScreenFrames

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
            height: list.isCollapsed ? NoteWindowMetrics.collapsedHeaderHeight : NoteWindowMetrics.headerHeight
        )

        let rootView = NoteView(list: list, presentation: presentation)
            .modelContainer(modelContainer)
            .environmentObject(coordinator)
            .environmentObject(settings)

        let hostingView = NSHostingView(rootView: rootView)
        // SwiftUI's minimum content size must never resize the native panel.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        observeWindowAppearance(settings: settings)
        applyWindowMode()

        if list.isCollapsed {
            panel.styleMask.remove(.resizable)
            setCollapsed(true, animated: false, persist: false)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        fitToScreens(visibleScreenFrames(), persist: false)
        window?.orderFrontRegardless()
    }

    func fitToScreens(_ screens: [NSRect], persist: Bool = true) {
        guard let panel = window,
              let placement = NoteScreenGeometry.fit(panel.frame, to: screens) else { return }
        if isChangingCollapseState {
            // The caller may save the other notes now; this note must be saved
            // after its deferred placement has actually been applied.
            pendingScreenFrames = screens
            return
        }
        isFittingToScreen = true
        pendingSave?.cancel()
        pendingSave = nil
        panel.minSize.width = min(NoteWindowMetrics.minimumWidth, placement.visibleFrame.width)
        if panel.frame != placement.frame {
            panel.setFrame(placement.frame, display: panel.isVisible)
            panel.contentView?.layoutSubtreeIfNeeded()
        }
        rememberCurrentFrame()
        if list.isCollapsed {
            if list.windowWidth != panel.frame.width { list.windowWidth = panel.frame.width }
            let expandedHeight = min(max(list.windowHeight, NoteWindowMetrics.headerHeight + 120),
                                     placement.visibleFrame.height)
            if list.windowHeight != expandedHeight { list.windowHeight = expandedHeight }
        }
        isFittingToScreen = false
        if persist { coordinator.saveContext() }
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

    func toggleCollapsed(animated: Bool = true) {
        setCollapsed(!requestedCollapsed, animated: animated)
    }

    func setCollapsed(_ collapsed: Bool, animated: Bool, persist: Bool = true) {
        guard let panel = window else { return }
        requestedCollapsed = collapsed
        if isChangingCollapseState {
            queuedRequest = (collapsed, animated, persist)
            return
        }
        var currentFrame = panel.frame
        var targetHeight = collapsed
            ? NoteWindowMetrics.collapsedHeaderHeight
            : max(list.windowHeight, NoteWindowMetrics.headerHeight + 120)
        if list.isCollapsed == collapsed && currentFrame.height == targetHeight {
            return
        }

        isChangingCollapseState = true
        pendingSave?.cancel()
        pendingSave = nil
        let rememberExpandedSize = collapsed && !list.isCollapsed
        presentation.phase = collapsed ? .collapsing : .expanding
        panel.styleMask.remove(.resizable)
        // In particular, do not raise this while expansion still starts at 34 pt.
        panel.minSize.height = NoteWindowMetrics.collapsedHeaderHeight
        if !collapsed {
            let expanded = NSRect(x: currentFrame.minX, y: currentFrame.maxY - targetHeight,
                                  width: currentFrame.width, height: targetHeight)
            if let placement = NoteScreenGeometry.fit(expanded, to: visibleScreenFrames()) {
                targetHeight = placement.frame.height
                // A collapsed note may have been moved near the bottom edge.
                // Establish a reachable expansion anchor before the animation.
                currentFrame = NSRect(x: placement.frame.minX,
                                      y: placement.frame.maxY - currentFrame.height,
                                      width: placement.frame.width, height: currentFrame.height)
                panel.minSize.width = min(NoteWindowMetrics.minimumWidth, placement.visibleFrame.width)
                panel.setFrame(currentFrame, display: panel.isVisible)
            }
        }
        panel.contentView?.layoutSubtreeIfNeeded()

        let update: (CGFloat) -> Void = { [weak panel] progress in
            let height = currentFrame.height + (targetHeight - currentFrame.height) * progress
            panel?.setFrame(NSRect(
                x: currentFrame.minX, y: currentFrame.maxY - height,
                width: currentFrame.width, height: height
            ), display: true)
            panel?.contentView?.layoutSubtreeIfNeeded()
        }
        let completion: () -> Void = { [weak self] in
            guard let self, let panel = self.window else { return }
            update(1)
            if rememberExpandedSize {
                self.list.windowHeight = currentFrame.height
                self.list.windowWidth = currentFrame.width
            }
            self.list.isCollapsed = collapsed
            self.presentation.phase = collapsed ? .collapsed : .expanded
            if !collapsed { panel.styleMask.insert(.resizable) }
            panel.minSize.height = collapsed
                ? NoteWindowMetrics.collapsedHeaderHeight : NoteWindowMetrics.headerHeight
            panel.contentView?.layoutSubtreeIfNeeded()
            self.isChangingCollapseState = false
            // A display change must not compete with the animation's captured
            // frame. Apply the latest layout before starting a queued toggle.
            let shouldPersist = persist || self.pendingScreenFrames != nil
            if let screens = self.pendingScreenFrames {
                self.pendingScreenFrames = nil
                self.fitToScreens(screens, persist: false)
            }
            if let request = self.queuedRequest {
                self.queuedRequest = nil
                if request.collapsed != collapsed {
                    self.setCollapsed(request.collapsed, animated: request.animated,
                                      persist: shouldPersist || request.persist)
                    return
                }
                self.rememberCurrentFrame()
                if shouldPersist || request.persist { self.coordinator.saveContext() }
            } else {
                self.rememberCurrentFrame()
                if shouldPersist { self.coordinator.saveContext() }
            }
        }
        if animated && !reduceMotion() {
            animationDriver.start(update: update, completion: completion)
        } else {
            completion()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        coordinator.noteDidBecomeActive(list)
    }

    func windowDidMove(_ notification: Notification) {
        guard !isChangingCollapseState && !isFittingToScreen else { return }
        rememberCurrentFrame()
        scheduleSave()
    }

    func windowDidResize(_ notification: Notification) {
        guard !isChangingCollapseState && !isFittingToScreen else { return }
        rememberCurrentFrame()
        scheduleSave()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard !isChangingCollapseState && !isFittingToScreen else { return }
        rememberCurrentFrame()
        pendingSave?.cancel()
        coordinator.saveContext()
    }

    private func rememberCurrentFrame() {
        guard let frame = window?.frame else { return }
        if list.windowX != frame.minX { list.windowX = frame.minX }
        if list.windowTop != frame.maxY { list.windowTop = frame.maxY }
        if !list.isCollapsed && !isChangingCollapseState {
            if list.windowWidth != frame.width { list.windowWidth = frame.width }
            if list.windowHeight != frame.height { list.windowHeight = frame.height }
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
