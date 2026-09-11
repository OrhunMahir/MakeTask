import AppKit
import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class NoteScreenRecoveryTests: XCTestCase {
    private final class ScreenLayout {
        var frames = [NSRect(x: 0, y: 40, width: 1200, height: 760)]
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
        let layout = ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let list = TodoList(title: "External display", windowX: 2500, windowTop: 1600,
                            windowWidth: 2000, windowHeight: 1400)
        environment.container.mainContext.insert(list)
        environment.coordinator.show(list)
        let panel = try XCTUnwrap(controller(for: list).window)
        XCTAssertTrue(panel is FloatingNotePanel)
        XCTAssertEqual(panel.frame, layout.frames[0])
        XCTAssertEqual(list.windowWidth, 1200)
        XCTAssertEqual(list.windowHeight, 760)
        try assertSaved(list, in: environment)
    }

    func testCollapsedRestorationKeepsHeaderPositionAndExpansionFitsAboveDock() throws {
        let layout = ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let list = TodoList(title: "Rolled up", windowX: 200, windowTop: 100,
                            windowWidth: 320, windowHeight: 1200, isCollapsed: true)
        environment.container.mainContext.insert(list)
        environment.coordinator.show(list)
        let controller = try controller(for: list)
        let panel = try XCTUnwrap(controller.window)
        XCTAssertEqual(panel.frame.maxY, 100)
        XCTAssertEqual(panel.frame.height, 34)
        XCTAssertTrue(list.isCollapsed)
        XCTAssertEqual(list.windowHeight, 760)
        controller.setCollapsed(false, animated: false)
        XCTAssertTrue(layout.frames[0].contains(panel.frame))
        XCTAssertEqual(panel.frame.width, 320)
        XCTAssertEqual(panel.frame.height, 760)
        XCTAssertFalse(list.isCollapsed)
        try assertSaved(list, in: environment)
    }

    func testDisplayNotificationRecoversVisibleAndHiddenPanelsWithoutChangingSelection() async throws {
        let layout = ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer {
            environment.coordinator.stop()
            environment.coordinator.hideAll()
            environment.cleanUp()
        }
        let visible = TodoList(title: "Visible", windowX: 850, windowTop: 780)
        let hidden = TodoList(title: "Hidden", sortOrder: 1, windowX: 800, windowTop: 750,
                              windowWidth: 400, windowHeight: 700, isCollapsed: true)
        environment.container.mainContext.insert(visible)
        environment.container.mainContext.insert(hidden)
        environment.coordinator.start(registerGlobalShortcuts: false)
        let visiblePanel = try XCTUnwrap(controller(for: visible).window)
        let hiddenPanel = try XCTUnwrap(controller(for: hidden).window)
        environment.coordinator.hide(hidden)
        environment.coordinator.noteDidBecomeActive(visible)
        layout.frames = [NSRect(x: 0, y: 60, width: 640, height: 420)]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(layout.frames[0].contains(visiblePanel.frame))
        XCTAssertTrue(layout.frames[0].contains(hiddenPanel.frame))
        XCTAssertTrue(visiblePanel.isVisible)
        XCTAssertFalse(hiddenPanel.isVisible)
        XCTAssertTrue(hidden.isHidden)
        XCTAssertTrue(hidden.isCollapsed)
        XCTAssertEqual(hiddenPanel.frame.height, 34)
        XCTAssertEqual(hidden.windowHeight, 420)
        XCTAssertEqual(environment.coordinator.activeListID, visible.id)
        try assertSaved(visible, in: environment)
        try assertSaved(hidden, in: environment)

        environment.coordinator.stop()
        let stoppedFrame = visiblePanel.frame
        layout.frames = [NSRect(x: -700, y: 60, width: 640, height: 420)]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(visiblePanel.frame, stoppedFrame)
    }

    func testRevealingCachedHiddenPanelUsesCurrentScreens() throws {
        let layout = ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.coordinator.hideAll(); environment.cleanUp() }
        let list = TodoList(title: "Cached", windowX: 800, windowTop: 780)
        environment.container.mainContext.insert(list)
        environment.coordinator.show(list)
        let original = try controller(for: list)
        environment.coordinator.hide(list)
        layout.frames = [NSRect(x: 0, y: 40, width: 600, height: 400)]
        environment.coordinator.show(list)
        XCTAssertTrue(try controller(for: list) === original)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(original.window).frame))
        XCTAssertFalse(list.isHidden)
        try assertSaved(list, in: environment)
    }

    func testDisplayChangeDuringCollapseWaitsThenPersistsLatestValidScreen() throws {
        let layout = ScreenLayout()
        var saves = 0
        let environment = try TestEnvironment(saveChanges: { context in
            saves += 1
            try context.save()
        }, visibleScreenFrames: { layout.frames })
        defer { environment.cleanUp() }
        let clock = ManualClock()
        let list = TodoList(title: "Animating", windowX: 800, windowTop: 780,
                            windowWidth: 320, windowHeight: 700)
        environment.container.mainContext.insert(list)
        try environment.container.mainContext.save()
        let controller = NoteWindowController(
            list: list, frame: NSRect(x: 800, y: 80, width: 320, height: 700),
            modelContainer: environment.container, coordinator: environment.coordinator,
            settings: environment.settings, animationDriver: clock, reduceMotion: { false },
            visibleScreenFrames: { layout.frames }
        )
        defer { controller.close() }
        controller.show()
        controller.setCollapsed(true, animated: true, persist: false)
        clock.advance(0.5)
        let midpoint = try XCTUnwrap(controller.window).frame
        layout.frames = [NSRect(x: 0, y: 40, width: 700, height: 500)]
        controller.fitToScreens(layout.frames, persist: false)
        layout.frames = [NSRect(x: 0, y: 60, width: 600, height: 400)]
        controller.fitToScreens(layout.frames, persist: false)
        controller.fitToScreens([], persist: false)
        XCTAssertEqual(controller.window?.frame, midpoint)
        XCTAssertEqual(list.windowTop, 780)
        XCTAssertEqual(list.windowHeight, 700)
        XCTAssertFalse(environment.container.mainContext.hasChanges)
        XCTAssertEqual(saves, 0)
        clock.advance(1)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(controller.window).frame))
        XCTAssertEqual(controller.window?.frame.height, 34)
        XCTAssertEqual(list.windowHeight, 400)
        XCTAssertTrue(list.isCollapsed)
        XCTAssertEqual(saves, 1)
        try assertSaved(list, in: environment)
    }

    func testDisplayChangeDuringExpansionAndQueuedCollapsePreserveExpandedSize() throws {
        let layout = ScreenLayout()
        let environment = try TestEnvironment(visibleScreenFrames: { layout.frames })
        defer { environment.cleanUp() }
        let clock = ManualClock()
        let list = TodoList(title: "Queued", windowX: 800, windowTop: 780,
                            windowWidth: 320, windowHeight: 700, isCollapsed: true)
        environment.container.mainContext.insert(list)
        try environment.container.mainContext.save()
        let controller = NoteWindowController(
            list: list, frame: NSRect(x: 800, y: 746, width: 320, height: 34),
            modelContainer: environment.container, coordinator: environment.coordinator,
            settings: environment.settings, animationDriver: clock, reduceMotion: { false },
            visibleScreenFrames: { layout.frames }
        )
        defer { controller.close() }
        controller.show()
        controller.toggleCollapsed()
        clock.advance(0.5)
        layout.frames = [NSRect(x: 0, y: 60, width: 600, height: 400)]
        controller.fitToScreens(layout.frames)
        controller.toggleCollapsed()
        clock.advance(1)
        XCTAssertEqual(controller.presentation.phase, .collapsing)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(controller.window).frame))
        clock.advance(1)
        XCTAssertEqual(controller.presentation.phase, .collapsed)
        XCTAssertEqual(controller.window?.frame.height, 34)
        XCTAssertEqual(list.windowHeight, 400)
        XCTAssertEqual(list.windowWidth, 320)
        try assertSaved(list, in: environment)
        controller.setCollapsed(false, animated: false)
        XCTAssertEqual(controller.window?.frame.height, 400)
        XCTAssertTrue(layout.frames[0].contains(try XCTUnwrap(controller.window).frame))
    }
}
