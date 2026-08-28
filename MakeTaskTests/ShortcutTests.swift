import AppKit
import Carbon.HIToolbox
import XCTest
@testable import MakeTask

@MainActor
final class ShortcutTests: XCTestCase {
    func testDefaultGlobalShortcutsMatchExpectedKeys() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }

        XCTAssertEqual(
            environment.settings.shortcut(for: .quickAdd),
            AppShortcut(keyCode: kVK_Space, modifiers: [.command, .shift])
        )
        XCTAssertEqual(
            environment.settings.shortcut(for: .toggleAllNotesVisibility),
            AppShortcut(keyCode: kVK_ANSI_H, modifiers: [.command, .shift])
        )
    }

    func testKeyboardEventsResolveToConfiguredActions() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }

        XCTAssertEqual(
            environment.settings.action(matching: keyEvent(
                keyCode: kVK_Space,
                characters: " ",
                modifiers: [.command, .shift]
            )),
            .quickAdd
        )
        XCTAssertEqual(
            environment.settings.action(matching: keyEvent(
                keyCode: kVK_ANSI_M,
                characters: "m",
                modifiers: .command
            )),
            .collapseCurrentNote
        )
    }

    func testDuplicateShortcutConflictsAreReported() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let shortcut = environment.settings.shortcut(for: .quickAdd)

        let conflicts = environment.settings.conflictingActions(
            for: shortcut,
            excluding: .toggleAllNotesVisibility
        )

        XCTAssertEqual(conflicts, [.quickAdd])
    }

    private func keyEvent(
        keyCode: Int,
        characters: String,
        modifiers: NSEvent.ModifierFlags
    ) -> NSEvent {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        ) else {
            fatalError("Could not create keyboard event")
        }
        return event
    }
}
