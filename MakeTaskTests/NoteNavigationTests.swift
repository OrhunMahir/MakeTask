import AppKit
import Carbon.HIToolbox
import XCTest
@testable import MakeTask

@MainActor
final class NoteNavigationTests: XCTestCase {
    private func candidate(_ x: CGFloat, _ top: CGFloat, height: CGFloat = 200) -> NoteNavigation.Candidate {
        .init(id: UUID(), frame: CGRect(x: x, y: top - height, width: 300, height: height))
    }

    func testGridNavigationUsesHeadersNotExpandedWindowCenters() {
        let origin = candidate(100, 800, height: 500)
        let right = candidate(450, 800, height: 34)
        let below = candidate(100, 250, height: 34)
        let diagonal = candidate(450, 250)
        let all = [diagonal, below, right]
        XCTAssertEqual(NoteNavigation.neighbor(from: origin.frame, in: .right, candidates: all), right.id)
        XCTAssertEqual(NoteNavigation.neighbor(from: origin.frame, in: .down, candidates: all), below.id)
        XCTAssertEqual(NoteNavigation.neighbor(from: right.frame, in: .left, candidates: [origin, below]), origin.id)
        XCTAssertEqual(NoteNavigation.neighbor(from: below.frame, in: .up, candidates: [right, origin]), origin.id)
        XCTAssertNil(NoteNavigation.neighbor(from: origin.frame, in: .up, candidates: all))
        XCTAssertNil(NoteNavigation.neighbor(from: origin.frame, in: .left, candidates: all))
    }

    func testOffsetNotesAndNegativeDisplayCoordinatesUseNearestDirection() {
        let origin = candidate(-900, 400)
        let near = candidate(-870, 160)
        let far = candidate(-900, -200)
        let beside = candidate(-520, 390)
        XCTAssertEqual(NoteNavigation.neighbor(from: origin.frame, in: .down,
                                               candidates: [far, beside, near]), near.id)
        XCTAssertEqual(NoteNavigation.neighbor(from: origin.frame, in: .right,
                                               candidates: [far, beside, near]), beside.id)
        XCTAssertEqual(NoteNavigation.neighbor(from: origin.frame, in: .down,
                                               candidates: [beside, far]), far.id)
    }

    func testCoincidentNotesDoNotMoveAndTiesAreStable() {
        let origin = candidate(100, 800)
        let same = candidate(100, 800, height: 34)
        XCTAssertNil(NoteNavigation.neighbor(from: origin.frame, in: .down, candidates: [same]))
        let a = candidate(100, 400)
        let b = candidate(100, 400)
        XCTAssertEqual(NoteNavigation.neighbor(from: origin.frame, in: .down, candidates: [a, b]),
                       NoteNavigation.neighbor(from: origin.frame, in: .down, candidates: [b, a]))
    }

    func testCommandArrowsTransferKeyWindowAcrossCollapsedAndExpandedNotes() throws {
        let env = try TestEnvironment(visibleScreenFrames: { [NSRect(x: 0, y: 0, width: 1200, height: 900)] })
        let lists = [TodoList(title: "Top left", sortOrder: 3),
                     TodoList(title: "Top right", sortOrder: 2, isCollapsed: true),
                     TodoList(title: "Bottom left", sortOrder: 1, isCollapsed: true),
                     TodoList(title: "Bottom right", sortOrder: 0)]
        var windows: [NSWindow] = []
        defer {
            windows.forEach { $0.close() }
            env.coordinator.stop()
            env.cleanUp()
        }
        for (index, list) in lists.enumerated() {
            env.container.mainContext.insert(list)
            env.coordinator.show(list)
            let window = try XCTUnwrap(NSApp.windows.first {
                ($0.windowController as? NoteWindowController)?.list.id == list.id
            })
            let height: CGFloat = list.isCollapsed ? 34 : 220
            window.setFrame(NSRect(x: index % 2 == 0 ? 100 : 460,
                                   y: (index < 2 ? 780 : 450) - height,
                                   width: 300, height: height), display: false)
            windows.append(window)
        }
        windows[0].makeKeyAndOrderFront(nil)
        windows[0].makeFirstResponder(windows[0].contentView)
        let steps: [(Int, Int, Int)] = [(0, kVK_DownArrow, 2), (2, kVK_RightArrow, 3),
                                       (3, kVK_UpArrow, 1), (1, kVK_LeftArrow, 0)]
        for (source, key, target) in steps {
            let event = try keyEvent(key, in: windows[source])
            XCTAssertNil(env.coordinator.handleLocalKeyEvent(event, in: windows[source]))
            XCTAssertEqual(env.coordinator.activeListID, lists[target].id)
            XCTAssertTrue(windows[target].isKeyWindow)
            XCTAssertTrue(windows[target].firstResponder === windows[target].contentView)
        }
        // A hidden nearest neighbor must not be revealed, and no wrap occurs.
        env.coordinator.hide(lists[2])
        XCTAssertNil(env.coordinator.handleLocalKeyEvent(try keyEvent(kVK_DownArrow, in: windows[0]), in: windows[0]))
        XCTAssertEqual(env.coordinator.activeListID, lists[0].id)
        XCTAssertTrue(lists[2].isHidden)
        // A user's mouse move takes effect immediately, independent of list order.
        windows[1].setFrameOrigin(NSPoint(x: 100, y: 600))
        XCTAssertNil(env.coordinator.handleLocalKeyEvent(try keyEvent(kVK_DownArrow, in: windows[0]), in: windows[0]))
        XCTAssertEqual(env.coordinator.activeListID, lists[1].id)
        XCTAssertTrue(lists[1].isCollapsed)
        XCTAssertFalse(env.coordinator.canUndo, "Navigation must not create data changes")
    }

    func testDefaultArrowShortcutsAreUniqueAndCustomizable() throws {
        let env = try TestEnvironment()
        defer { env.cleanUp() }
        let actions: [AppShortcutAction] = [.selectListLeft, .selectListRight, .selectListAbove, .selectListBelow]
        for (action, key) in zip(actions, [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]) {
            let event = try keyEvent(key)
            XCTAssertEqual(env.settings.action(matching: event), action)
            XCTAssertTrue(env.settings.conflictingActions(for: action.defaultShortcut, excluding: action).isEmpty)
        }
        env.settings.setShortcut(AppShortcut(keyCode: kVK_ANSI_J, modifiers: [.command]), for: .selectListBelow)
        XCTAssertEqual(env.settings.action(matching: try keyEvent(kVK_ANSI_J)), .selectListBelow)
        XCTAssertNil(env.settings.action(matching: try keyEvent(kVK_DownArrow)))
    }

    private func keyEvent(_ key: Int, in window: NSWindow? = nil) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command],
                                     timestamp: 0, windowNumber: window?.windowNumber ?? 0, context: nil,
                                     characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                                     keyCode: UInt16(key)))
    }
}
