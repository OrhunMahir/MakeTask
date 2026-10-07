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

    func testHeaderReleasesBodyEditorButKeepsTitleEditorAndBodyClicks() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let panel = try XCTUnwrap(fixture.panel as? FloatingNotePanel)
        var resetCount = 0
        panel.onHeaderMouseDown = { resetCount += 1 }
        let editor = NSTextView()
        fixture.focus(editor)
        editor.frame = panel.contentView!.convert(NSRect(x: 10, y: 10, width: 200, height: 30), from: nil)
        panel.prepareForHeaderInteraction(at: NSPoint(x: 40, y: 40))
        XCTAssertTrue(panel.firstResponder === editor)
        XCTAssertEqual(resetCount, 0)
        panel.prepareForHeaderInteraction(at: NSPoint(x: 40, y: panel.frame.height - 10))
        XCTAssertFalse(panel.firstResponder === editor)
        XCTAssertEqual(resetCount, 1)
        editor.frame = panel.contentView!.convert(NSRect(x: 10, y: panel.frame.height - 30, width: 200, height: 20), from: nil)
        XCTAssertTrue(panel.makeFirstResponder(editor))
        panel.prepareForHeaderInteraction(at: NSPoint(x: 40, y: panel.frame.height - 10))
        XCTAssertTrue(panel.firstResponder === editor, "Clicking a list-title editor must retain its caret")
    }

    func testHeaderResetClearsSelectionAndSavesDraftInHostedNote() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let task = TodoTask(title: "Original", list: fixture.controller.list)
        fixture.environment.container.mainContext.insert(task)
        fixture.controller.activateAndFocus()
        try await Task.sleep(for: .milliseconds(100))
        func command(_ command: NoteKeyboardCommand) {
            fixture.environment.coordinator.noteKeyboardCommand = NoteKeyboardCommandEvent(
                listID: fixture.controller.list.id, command: command)
        }
        command(.selectNextTask)
        command(.editSelectedTask)
        try await Task.sleep(for: .milliseconds(100))
        let editor = try XCTUnwrap(fixture.panel.firstResponder as? NSTextView)
        editor.selectAll(nil)
        editor.insertText("Saved draft", replacementRange: editor.selectedRange())
        try await Task.sleep(for: .milliseconds(50))
        let panel = try XCTUnwrap(fixture.panel as? FloatingNotePanel)
        panel.prepareForHeaderInteraction(at: NSPoint(x: 40, y: panel.frame.height - 10))
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(task.title, "Saved draft")
        command(.toggleSelectedTask)
        command(.editSelectedTask)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(task.isCompleted)
        XCTAssertFalse(fixture.panel.firstResponder is NSTextView)
    }

    func testCollapseResignsEditorAndBlocksTaskCommandsUntilExpanded() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let editor = NSTextView()
        fixture.focus(editor)
        fixture.controller.setCollapsed(true, animated: false)
        XCTAssertFalse(fixture.panel.firstResponder === editor)
        for action: AppShortcutAction in [.completeSelectedTask, .editSelectedTask, .deleteSelectedTask, .selectNextTask] {
            let event = try keyEvent(action.defaultShortcut, window: fixture.panel)
            XCTAssertFalse(NoteKeyboardRouting.allows(action, event: event, in: fixture.panel))
        }
        let collapse = try keyEvent(AppShortcutAction.collapseCurrentNote.defaultShortcut, window: fixture.panel)
        XCTAssertTrue(NoteKeyboardRouting.allows(.collapseCurrentNote, event: collapse, in: fixture.panel))
        fixture.controller.setCollapsed(false, animated: false)
        let space = try keyEvent(AppShortcutAction.completeSelectedTask.defaultShortcut, window: fixture.panel)
        XCTAssertTrue(NoteKeyboardRouting.allows(.completeSelectedTask, event: space, in: fixture.panel))
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
