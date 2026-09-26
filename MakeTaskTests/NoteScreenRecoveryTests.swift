import AppKit
import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class NoteScreenRecoveryTests: XCTestCase {
    private final class ScreenLayout {
        let initial: NSRect
        var frames: [NSRect]

        init() throws {
            // Injecting screen geometry does not replace AppKit's real screen.
            // Keep native panels inside it so AppKit cannot independently move
            // them (the CI runner has less usable height than a local display).
            let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
            let available = screen.visibleFrame.insetBy(dx: 20, dy: 20)
            initial = NSRect(x: available.minX, y: available.minY,
                             width: min(available.width, 1000), height: min(available.height, 600))
            frames = [initial]
        }

        var expandedNote: NSRect {
            NSRect(x: initial.maxX - 340, y: initial.minY + 20,
                   width: 320, height: initial.height - 40)
        }

        var reduced: NSRect {
            NSRect(x: initial.minX, y: initial.minY + 20,
                   width: floor(initial.width * 0.6), height: floor(initial.height * 0.6))
        }
    }

    private final class ManualClock: NoteCollapseAnimationDriving {
        var update: ((CGFloat) -> Void)?
        var completion: (() -> Void)?

        func start(update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
            self.update = update
            self.completion = completion
        }

        func advance(_ progress: CGFloat) {
            update?(progress)
            if progress == 1 {
                let finish = completion
                update = nil
                completion = nil
                finish?()
            }
        }
    }

    private func controller(for list: TodoList) throws -> NoteWindowController {
        try XCTUnwrap(NSApp.windows.compactMap { $0.windowController as? NoteWindowController }
            .first { $0.list === list })
    }

    private func assertSaved(_ list: TodoList, in environment: TestEnvironment,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let context = ModelContext(environment.container)
        let id = list.id
        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<TodoList>(
            predicate: #Predicate { $0.id == id }
        )).first, file: file, line: line)
        XCTAssertEqual(stored.windowX, list.windowX, file: file, line: line)
        XCTAssertEqual(stored.windowTop, list.windowTop, file: file, line: line)
        XCTAssertEqual(stored.windowWidth, list.windowWidth, file: file, line: line)
        XCTAssertEqual(stored.windowHeight, list.windowHeight, file: file, line: line)
        XCTAssertEqual(stored.isCollapsed, list.isCollapsed, file: file, line: line)
    }

    func testRestorationRecoversDisconnectedMonitorAndOversizedSavedWindow() throws {
        let layout = try ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let list = TodoList(title: "External display",
                            windowX: layout.initial.maxX + 1000, windowTop: layout.initial.maxY + 800,
                            windowWidth: layout.initial.width + 800, windowHeight: layout.initial.height + 600)
        environment.container.mainContext.insert(list)
        environment.coordinator.show(list)
        let panel = try XCTUnwrap(controller(for: list).window)
        XCTAssertTrue(panel is FloatingNotePanel)
        XCTAssertEqual(panel.frame, layout.frames[0])
        XCTAssertEqual(list.windowWidth, layout.initial.width)
        XCTAssertEqual(list.windowHeight, layout.initial.height)
        try assertSaved(list, in: environment)
    }

    func testCollapsedRestorationKeepsHeaderPositionAndExpansionFitsAboveDock() throws {
        let layout = try ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let top = layout.initial.minY + 60
        let list = TodoList(title: "Rolled up", windowX: layout.expandedNote.minX, windowTop: top,
                            windowWidth: 320, windowHeight: layout.initial.height + 400, isCollapsed: true)
        environment.container.mainContext.insert(list)
        environment.coordinator.show(list)
        let controller = try controller(for: list)
        let panel = try XCTUnwrap(controller.window)
        XCTAssertEqual(panel.frame.maxY, top)
        XCTAssertEqual(panel.frame.height, 34)
        XCTAssertTrue(list.isCollapsed)
        XCTAssertEqual(list.windowHeight, layout.initial.height)
        controller.setCollapsed(false, animated: false)
        XCTAssertTrue(layout.frames[0].contains(panel.frame))
        XCTAssertEqual(panel.frame.width, 320)
        XCTAssertEqual(panel.frame.height, layout.initial.height)
        XCTAssertFalse(list.isCollapsed)
        try assertSaved(list, in: environment)
    }

    func testDisplayNotificationRecoversVisibleAndHiddenPanelsWithoutChangingSelection() async throws {
        let layout = try ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer {
            environment.coordinator.stop()
            environment.coordinator.hideAll()
            environment.cleanUp()
        }
        let visible = TodoList(title: "Visible", windowX: layout.expandedNote.minX,
                               windowTop: layout.expandedNote.maxY)
        let hidden = TodoList(title: "Hidden", sortOrder: 1, windowX: layout.initial.maxX - 420,
                              windowTop: layout.expandedNote.maxY, windowWidth: 400,
                              windowHeight: layout.expandedNote.height, isCollapsed: true)
        environment.container.mainContext.insert(visible)
        environment.container.mainContext.insert(hidden)
        environment.coordinator.start(registerGlobalShortcuts: false)
        let visiblePanel = try XCTUnwrap(controller(for: visible).window)
        let hiddenPanel = try XCTUnwrap(controller(for: hidden).window)
        environment.coordinator.hide(hidden)
        environment.coordinator.noteDidBecomeActive(visible)
        layout.frames = [layout.reduced]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(layout.frames[0].contains(visiblePanel.frame))
        XCTAssertTrue(layout.frames[0].contains(hiddenPanel.frame))
        XCTAssertTrue(visiblePanel.isVisible)
        XCTAssertFalse(hiddenPanel.isVisible)
        XCTAssertTrue(hidden.isHidden)
        XCTAssertTrue(hidden.isCollapsed)
        XCTAssertEqual(hiddenPanel.frame.height, 34)
        XCTAssertEqual(hidden.windowHeight, layout.reduced.height)
        XCTAssertEqual(environment.coordinator.activeListID, visible.id)
        try assertSaved(visible, in: environment)
        try assertSaved(hidden, in: environment)

        environment.coordinator.stop()
        let stoppedFrame = visiblePanel.frame
        layout.frames = [layout.reduced.offsetBy(dx: layout.initial.width - layout.reduced.width,
                                                 dy: layout.initial.height - layout.reduced.height - 20)]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(visiblePanel.frame, stoppedFrame)
    }

    func testRevealingCachedHiddenPanelUsesCurrentScreens() throws {
        let layout = try ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let list = TodoList(title: "Cached", windowX: layout.expandedNote.minX,
                            windowTop: layout.expandedNote.maxY)
        environment.container.mainContext.insert(list)
        environment.coordinator.show(list)
        let original = try controller(for: list)
        environment.coordinator.hide(list)
        layout.frames = [layout.reduced]
        environment.coordinator.show(list)
        XCTAssertTrue(try controller(for: list) === original)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(original.window).frame))
        XCTAssertFalse(list.isHidden)
        try assertSaved(list, in: environment)
    }

    func testDisplayChangeDuringCollapseWaitsThenPersistsLatestValidScreen() throws {
        let layout = try ScreenLayout()
        var saves = 0
        let environment = try TestEnvironment(saveChanges: { context in
            saves += 1
            try context.save()
        }, visibleScreenFrames: { layout.frames })
        defer { environment.cleanUp() }
        let clock = ManualClock()
        let initialFrame = layout.expandedNote
        let list = TodoList(title: "Animating", windowX: initialFrame.minX, windowTop: initialFrame.maxY,
                            windowWidth: initialFrame.width, windowHeight: initialFrame.height)
        environment.container.mainContext.insert(list)
        try environment.container.mainContext.save()
        let controller = NoteWindowController(
            list: list, frame: initialFrame,
            modelContainer: environment.container, coordinator: environment.coordinator,
            settings: environment.settings, animationDriver: clock, reduceMotion: { false },
            visibleScreenFrames: { layout.frames }
        )
        defer { controller.close() }
        controller.show()
        XCTAssertEqual(controller.window?.frame, initialFrame)
        controller.setCollapsed(true, animated: true, persist: false)
        clock.advance(0.5)
        let midpoint = try XCTUnwrap(controller.window).frame
        layout.frames = [layout.initial.insetBy(dx: 20, dy: 20)]
        controller.fitToScreens(layout.frames, persist: false)
        layout.frames = [layout.reduced]
        controller.fitToScreens(layout.frames, persist: false)
        controller.fitToScreens([], persist: false)
        XCTAssertEqual(controller.window?.frame, midpoint)
        XCTAssertEqual(list.windowTop, initialFrame.maxY)
        XCTAssertEqual(list.windowHeight, initialFrame.height)
        XCTAssertFalse(environment.container.mainContext.hasChanges)
        XCTAssertEqual(saves, 0)
        clock.advance(1)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(controller.window).frame))
        XCTAssertEqual(controller.window?.frame.height, 34)
        XCTAssertEqual(list.windowHeight, layout.reduced.height)
        XCTAssertTrue(list.isCollapsed)
        XCTAssertEqual(saves, 1)
        try assertSaved(list, in: environment)
    }

    func testDisplayChangeDuringExpansionAndQueuedCollapsePreserveExpandedSize() throws {
        let layout = try ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.cleanUp() }
        let clock = ManualClock()
        let initialFrame = layout.expandedNote
        let list = TodoList(title: "Queued", windowX: initialFrame.minX, windowTop: initialFrame.maxY,
                            windowWidth: initialFrame.width, windowHeight: initialFrame.height, isCollapsed: true)
        environment.container.mainContext.insert(list)
        try environment.container.mainContext.save()
        let controller = NoteWindowController(
            list: list, frame: NSRect(x: initialFrame.minX, y: initialFrame.maxY - 34,
                                     width: initialFrame.width, height: 34),
            modelContainer: environment.container, coordinator: environment.coordinator,
            settings: environment.settings, animationDriver: clock, reduceMotion: { false },
            visibleScreenFrames: { layout.frames }
        )
        defer { controller.close() }
        controller.show()
        controller.toggleCollapsed()
        clock.advance(0.5)
        layout.frames = [layout.reduced]
        controller.fitToScreens(layout.frames)
        controller.toggleCollapsed()
        clock.advance(1)
        XCTAssertEqual(controller.presentation.phase, .collapsing)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(controller.window).frame))
        clock.advance(1)
        XCTAssertEqual(controller.presentation.phase, .collapsed)
        XCTAssertEqual(controller.window?.frame.height, 34)
        XCTAssertEqual(list.windowHeight, layout.reduced.height)
        XCTAssertEqual(list.windowWidth, min(initialFrame.width, layout.reduced.width))
        try assertSaved(list, in: environment)
        controller.setCollapsed(false, animated: false)
        XCTAssertEqual(controller.window?.frame.height, layout.reduced.height)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(controller.window).frame))
    }
}
