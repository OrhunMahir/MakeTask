import AppKit
import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class NoteWindowControllerTests: XCTestCase {
    private final class ManualClock: NoteCollapseAnimationDriving {
        var update: ((CGFloat) -> Void)?
        var completion: (() -> Void)?
        var starts = 0

        func start(update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
            starts += 1
            self.update = update
            self.completion = completion
        }

        func advance(_ fraction: CGFloat) {
            update?(fraction)
            if fraction == 1 {
                let finish = completion
                update = nil
                completion = nil
                finish?()
            }
        }
    }

    @MainActor
    private struct Fixture {
        let environment: TestEnvironment
        let controller: NoteWindowController
        let clock: ManualClock
        var panel: NSWindow { controller.window! }
        var list: TodoList { controller.list }

        init(collapsed: Bool = false, reduceMotion: Bool = false, realClock: Bool = false) throws {
            environment = try TestEnvironment()
            clock = ManualClock()
            let list = TodoList(title: "To do", windowX: 200, windowTop: 700,
                                windowWidth: 320, windowHeight: 360, isCollapsed: collapsed)
            environment.container.mainContext.insert(list)
            try environment.container.mainContext.save()
            controller = NoteWindowController(
                list: list,
                frame: NSRect(x: 200, y: collapsed ? 666 : 340, width: 320, height: collapsed ? 34 : 360),
                modelContainer: environment.container, coordinator: environment.coordinator,
                settings: environment.settings,
                animationDriver: realClock ? NoteCollapseAnimationDriver() : clock,
                reduceMotion: { reduceMotion },
                visibleScreenFrames: { [NSRect(x: 0, y: 0, width: 1440, height: 900)] }
            )
            controller.show()
            panel.contentView?.layoutSubtreeIfNeeded()
        }

        func cleanUp() {
            controller.close()
            environment.cleanUp()
        }
    }

    private func titleY(_ fixture: Fixture) throws -> CGFloat {
        fixture.panel.contentView?.layoutSubtreeIfNeeded()
        func find(_ view: NSView) -> NSView? {
            if view.identifier?.rawValue == "note.title-layout" { return view }
            return view.subviews.lazy.compactMap(find).first
        }
        let view = try XCTUnwrap(fixture.panel.contentView.flatMap(find))
        XCTAssertGreaterThan(view.bounds.width, 0)
        XCTAssertGreaterThan(view.bounds.height, 0)
        return fixture.panel.convertToScreen(view.convert(view.bounds, to: nil)).midY
    }

    private func assertGeometry(_ fixture: Fixture, height: CGFloat, title: CGFloat,
                                file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(fixture.panel is FloatingNotePanel, file: file, line: line)
        XCTAssertEqual(fixture.panel.frame.height, height, accuracy: 0.6, file: file, line: line)
        XCTAssertEqual(fixture.panel.frame.width, 320, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(fixture.panel.frame.maxY, 700, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(try titleY(fixture), title, accuracy: 0.6, file: file, line: line)
    }

    func testCollapseStartMidEndKeepsTitleAndTopAnchored() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let title = try titleY(fixture)
        fixture.controller.setCollapsed(true, animated: true)
        XCTAssertEqual(fixture.controller.presentation.phase, .collapsing)
        XCTAssertFalse(fixture.controller.presentation.showsBody)
        XCTAssertFalse(fixture.list.isCollapsed)
        try assertGeometry(fixture, height: 360, title: title)
        fixture.clock.advance(0.5)
        try assertGeometry(fixture, height: 197, title: title)
        XCTAssertEqual(fixture.list.windowHeight, 360)
        XCTAssertEqual(fixture.list.windowTop, 700)
        XCTAssertFalse(fixture.environment.container.mainContext.hasChanges)
        fixture.clock.advance(1)
        try assertGeometry(fixture, height: 34, title: title)
        XCTAssertTrue(fixture.list.isCollapsed)
        XCTAssertEqual(fixture.controller.presentation.phase, .collapsed)
        XCTAssertFalse(fixture.panel.styleMask.contains(.resizable))
        XCTAssertEqual(fixture.panel.minSize.height, 34)
    }

    func testExpansionStartMidEndDefersBodyAndMinimumSize() throws {
        let fixture = try Fixture(collapsed: true)
        defer { fixture.cleanUp() }
        let title = try titleY(fixture)
        fixture.controller.setCollapsed(false, animated: true)
        XCTAssertEqual(fixture.controller.presentation.phase, .expanding)
        try assertGeometry(fixture, height: 34, title: title)
        XCTAssertEqual(fixture.panel.minSize.height, 34)
        fixture.clock.advance(0.5)
        try assertGeometry(fixture, height: 197, title: title)
        XCTAssertFalse(fixture.controller.presentation.showsBody)
        XCTAssertTrue(fixture.list.isCollapsed)
        XCTAssertFalse(fixture.environment.container.mainContext.hasChanges)
        fixture.clock.advance(1)
        try assertGeometry(fixture, height: 360, title: title)
        XCTAssertTrue(fixture.controller.presentation.showsBody)
        XCTAssertFalse(fixture.list.isCollapsed)
        XCTAssertEqual(fixture.panel.minSize.height, 46)
        XCTAssertTrue(fixture.panel.styleMask.contains(.resizable))
    }

    func testRapidTogglesHonorLatestRequest() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let title = try titleY(fixture)
        fixture.controller.toggleCollapsed()
        fixture.clock.advance(0.5)
        fixture.controller.toggleCollapsed()
        fixture.clock.advance(1)
        XCTAssertEqual(fixture.controller.presentation.phase, .expanding)
        fixture.clock.advance(0.5)
        try assertGeometry(fixture, height: 197, title: title)
        fixture.clock.advance(1)
        try assertGeometry(fixture, height: 360, title: title)
        XCTAssertFalse(fixture.list.isCollapsed)
        XCTAssertEqual(fixture.clock.starts, 2)
        fixture.controller.toggleCollapsed()
        fixture.controller.toggleCollapsed()
        fixture.controller.toggleCollapsed()
        fixture.clock.advance(1)
        XCTAssertTrue(fixture.list.isCollapsed)
        XCTAssertEqual(fixture.clock.starts, 3)
    }

    func testReduceMotionAndNonanimatedTransitionsAreSynchronous() throws {
        for reduceMotion in [false, true] {
            let fixture = try Fixture(reduceMotion: reduceMotion)
            defer { fixture.cleanUp() }
            let title = try titleY(fixture)
            fixture.controller.setCollapsed(true, animated: reduceMotion)
            try assertGeometry(fixture, height: 34, title: title)
            XCTAssertTrue(fixture.list.isCollapsed)
            fixture.controller.setCollapsed(false, animated: reduceMotion)
            try assertGeometry(fixture, height: 360, title: title)
            XCTAssertFalse(fixture.list.isCollapsed)
            XCTAssertEqual(fixture.clock.starts, 0)
        }
    }

    func testRealClockKeepsTitleAnchoredAcrossBothTransitions() async throws {
        let fixture = try Fixture(realClock: true)
        defer { fixture.cleanUp() }
        let title = try titleY(fixture)
        for collapsed in [true, false] {
            fixture.controller.setCollapsed(collapsed, animated: true)
            var intermediateSamples = 0
            for _ in 0..<40 {
                try await Task.sleep(for: .milliseconds(10))
                XCTAssertEqual(fixture.panel.frame.maxY, 700, accuracy: 0.6)
                XCTAssertEqual(try titleY(fixture), title, accuracy: 0.6)
                if fixture.panel.frame.height > 34 && fixture.panel.frame.height < 360 {
                    intermediateSamples += 1
                }
                if fixture.controller.presentation.phase == (collapsed ? .collapsed : .expanded) { break }
            }
            XCTAssertGreaterThan(intermediateSamples, 0)
            try assertGeometry(fixture, height: collapsed ? 34 : 360, title: title)
            XCTAssertEqual(fixture.list.isCollapsed, collapsed)
        }
    }
}
