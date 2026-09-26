import AppKit
import Carbon.HIToolbox
import SwiftUI
import XCTest
@testable import MakeTask

@MainActor
final class NoteKeyboardRoutingTests: XCTestCase {
    @MainActor
    private struct Fixture {
        let environment: TestEnvironment
        let controller: NoteWindowController
        var panel: NSWindow { controller.window! }

        init() throws {
            environment = try TestEnvironment()
            let list = TodoList(title: "Keyboard routing")
            environment.container.mainContext.insert(list)
            environment.coordinator.noteDidBecomeActive(list)
            controller = NoteWindowController(
                list: list, frame: NSRect(x: 200, y: 300, width: 320, height: 360),
                modelContainer: environment.container,
                coordinator: environment.coordinator, settings: environment.settings
            )
        }

        func focus(_ view: NSView) {
            view.frame = NSRect(x: 10, y: 10, width: 200, height: 30)
            panel.contentView!.addSubview(view)
            XCTAssertTrue(panel.makeFirstResponder(view))
            XCTAssertTrue(panel.firstResponder === view)
        }

        func cleanUp() {
            controller.close()
            environment.cleanUp()
        }
    }

    func testNativeDetailControlsKeepTaskNavigationAndEditingKeys() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let controls: [NSView] = [
            NSDatePicker(), NSButton(checkboxWithTitle: "Due", target: nil, action: nil),
            NSButton(title: "Subtask", target: nil, action: nil),
            NSPopUpButton(), NSTextView()
        ]
        let actions: [AppShortcutAction] = [
            .completeSelectedTask, .editSelectedTask, .selectPreviousTask, .selectNextTask,
            .deleteSelectedTask, .moveSelectedTaskUp, .moveSelectedTaskDown,
            .moveTaskToPreviousList, .deleteCurrentNote, .undo, .redo
        ]
        for control in controls {
            fixture.focus(control)
            for action in actions {
                let event = try keyEvent(action.defaultShortcut, window: fixture.panel)
                XCTAssertTrue(fixture.environment.coordinator.handleLocalKeyEvent(event, in: fixture.panel) === event,
                              "\(type(of: control)) must retain \(action)")
                XCTAssertNil(fixture.environment.coordinator.noteKeyboardCommand)
            }
            control.removeFromSuperview()
        }
    }

    func testNoteCanvasStillRoutesTaskShortcutsAfterControlResignsFocus() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.focus(NSDatePicker())
        XCTAssertTrue(fixture.panel.makeFirstResponder(fixture.panel.contentView))
        let event = try keyEvent(AppShortcutAction.completeSelectedTask.defaultShortcut, window: fixture.panel)
        XCTAssertNil(fixture.environment.coordinator.handleLocalKeyEvent(event, in: fixture.panel))
        XCTAssertEqual(fixture.environment.coordinator.noteKeyboardCommand?.command, .toggleSelectedTask)
        XCTAssertEqual(fixture.environment.coordinator.noteKeyboardCommand?.listID, fixture.controller.list.id)
    }

    func testSelectedTaskRowRetainsCanvasShortcuts() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.focus(TaskDragSourceNSView())
        let event = try keyEvent(AppShortcutAction.editSelectedTask.defaultShortcut, window: fixture.panel)
        XCTAssertNil(fixture.environment.coordinator.handleLocalKeyEvent(event, in: fixture.panel))
        XCTAssertEqual(fixture.environment.coordinator.noteKeyboardCommand?.command, .editSelectedTask)
    }

    func testRemappedWindowActionsDoNotStealControlKeys() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.focus(NSDatePicker())
        for key in [kVK_Space, kVK_Return, kVK_UpArrow, kVK_DownArrow, kVK_Escape] {
            let event = try keyEvent(AppShortcut(keyCode: key), window: fixture.panel)
            for action: AppShortcutAction in [.hideCurrentNote, .collapseCurrentNote, .searchTasks] {
                XCTAssertFalse(NoteKeyboardRouting.allows(action, event: event, in: fixture.panel))
            }
        }
        let escape = AppShortcut(keyCode: kVK_Escape)
        fixture.environment.settings.setShortcut(escape, for: .hideCurrentNote)
        let event = try keyEvent(escape, window: fixture.panel)
        XCTAssertTrue(fixture.environment.coordinator.handleLocalKeyEvent(event, in: fixture.panel) === event)
        XCTAssertFalse(fixture.controller.list.isHidden)
    }

    func testExplicitWindowCommandsRemainAvailableWhileEditing() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.focus(NSTextView())
        for action: AppShortcutAction in [.hideCurrentNote, .collapseCurrentNote, .searchTasks] {
            let event = try keyEvent(action.defaultShortcut, window: fixture.panel)
            XCTAssertTrue(NoteKeyboardRouting.allows(action, event: event, in: fixture.panel))
        }
    }

    func testUnrelatedWindowDoesNotReceiveNoteCommands() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let settingsWindow = NSWindow(contentRect: .zero, styleMask: .titled, backing: .buffered, defer: false)
        settingsWindow.isReleasedWhenClosed = false
        defer { settingsWindow.close() }
        for action: AppShortcutAction in [.completeSelectedTask, .undo, .newList, .hideCurrentNote] {
            let event = try keyEvent(action.defaultShortcut, window: settingsWindow)
            XCTAssertTrue(fixture.environment.coordinator.handleLocalKeyEvent(event, in: settingsWindow) === event)
        }
        XCTAssertNil(fixture.environment.coordinator.noteKeyboardCommand)
        XCTAssertFalse(fixture.controller.list.isHidden)
    }

    func testAttachedSheetKeepsDefaultAndWindowCommands() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                             styleMask: .titled, backing: .buffered, defer: false)
        sheet.isReleasedWhenClosed = false
        fixture.controller.show()
        fixture.panel.beginSheet(sheet)
        defer { fixture.panel.endSheet(sheet); sheet.orderOut(nil) }
        XCTAssertTrue(fixture.panel.attachedSheet === sheet)
        for action: AppShortcutAction in [.editSelectedTask, .hideCurrentNote, .deleteSelectedTask] {
            let event = try keyEvent(action.defaultShortcut, window: fixture.panel)
            XCTAssertTrue(fixture.environment.coordinator.handleLocalKeyEvent(event, in: fixture.panel) === event)
        }
        XCTAssertNil(fixture.environment.coordinator.noteKeyboardCommand)
    }

    private struct FocusedButtonView: View {
        @FocusState private var isFocused: Bool
        let focusChanged: (Bool) -> Void

        var body: some View {
            Button("Detail action") {}
                .buttonStyle(.plain)
                // Exercise SwiftUI focus even when system keyboard navigation is off.
                .focusable(interactions: .edit)
                .focused($isFocused)
                .onChange(of: isFocused) { _, value in focusChanged(value) }
                .onAppear { isFocused = true }
        }
    }

    func testSwiftUIButtonFocusKeepsSpace() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        var buttonHasFocus = false
        fixture.panel.contentView = NSHostingView(rootView: FocusedButtonView { buttonHasFocus = $0 })
        fixture.controller.activateAndFocus()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(buttonHasFocus, "The test must actually focus the SwiftUI control")
        let responder = try XCTUnwrap(fixture.panel.firstResponder)
        let event = try keyEvent(AppShortcutAction.completeSelectedTask.defaultShortcut, window: fixture.panel)
        XCTAssertTrue(fixture.environment.coordinator.handleLocalKeyEvent(event, in: fixture.panel) === event,
                      "SwiftUI button focus uses \(type(of: responder))")
    }

    private func keyEvent(_ shortcut: AppShortcut, window: NSWindow) throws -> NSEvent {
        var flags: NSEvent.ModifierFlags = []
        if shortcut.modifiers.contains(.command) { flags.insert(.command) }
        if shortcut.modifiers.contains(.shift) { flags.insert(.shift) }
        if shortcut.modifiers.contains(.option) { flags.insert(.option) }
        if shortcut.modifiers.contains(.control) { flags.insert(.control) }
        return try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "",
            charactersIgnoringModifiers: "", isARepeat: false, keyCode: shortcut.keyCode
        ))
    }
}
