import AppKit
import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class RuntimeIssueTests: XCTestCase {
    private final class HotKey: GlobalHotKeyRegistering {
        var onPressed: (() -> Void)?
        var fails = false
        var isRegistered = false

        func register(keyCode: UInt32, modifiers: UInt32) throws {
            if fails { throw GlobalHotKeyService.HotKeyError.registrationFailed(-9878) }
            isRegistered = true
        }
        func unregister() { isRegistered = false }
    }

    func testSaveFailureStaysVisibleUntilSuccessfulRetry() throws {
        var fails = true
        let environment = try TestEnvironment(saveChanges: { context in
            if fails { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        }, makeHotKeyService: { _ in HotKey() })
        defer { environment.coordinator.stop(); environment.cleanUp() }
        environment.coordinator.start()
        let list = TodoList(title: "Not saved yet", isHidden: true)
        environment.container.mainContext.insert(list)
        environment.coordinator.saveContext()
        XCTAssertNotNil(environment.coordinator.persistenceError)
        XCTAssertTrue(environment.coordinator.hasRuntimeIssues)
        XCTAssertTrue(environment.container.mainContext.hasChanges)
        environment.coordinator.errorMessage = nil
        XCTAssertNil(environment.coordinator.reloadGlobalShortcuts())
        XCTAssertNotNil(environment.coordinator.persistenceError)
        fails = false
        environment.coordinator.saveContext()
        XCTAssertNil(environment.coordinator.persistenceError)
        XCTAssertFalse(environment.coordinator.hasRuntimeIssues)
        let verification = ModelContext(environment.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<TodoList>()).first?.title, list.title)
    }

    func testFailedShortcutIsNotAdvertisedAndRetryRecoversIt() throws {
        let quickAdd = HotKey()
        quickAdd.fails = true
        let visibility = HotKey()
        let environment = try TestEnvironment(makeHotKeyService: { $0 == 1 ? quickAdd : visibility })
        defer { environment.coordinator.stop(); environment.cleanUp() }
        environment.coordinator.start()
        XCTAssertNotNil(environment.coordinator.globalShortcutErrors[.quickAdd])
        XCTAssertNil(environment.coordinator.globalShortcutDescription(for: .quickAdd))
        XCTAssertNotNil(environment.coordinator.globalShortcutDescription(for: .toggleAllNotesVisibility))
        XCTAssertTrue(visibility.isRegistered)
        environment.coordinator.saveContext()
        XCTAssertTrue(environment.coordinator.hasRuntimeIssues)
        quickAdd.fails = false
        XCTAssertNil(environment.coordinator.reloadGlobalShortcuts())
        XCTAssertEqual(environment.coordinator.globalShortcutDescription(for: .quickAdd),
                       environment.settings.quickAddShortcutDescription)
        XCTAssertFalse(environment.coordinator.hasRuntimeIssues)
    }

    func testHandlerInstallationFailureIsVisibleAndRetriedIndependently() throws {
        var fails = true
        let environment = try TestEnvironment(makeHotKeyService: { identifier in
            if identifier == 1 && fails { throw GlobalHotKeyService.HotKeyError.handlerInstallationFailed(-50) }
            return HotKey()
        })
        defer { environment.coordinator.stop(); environment.cleanUp() }
        environment.coordinator.start()
        XCTAssertNotNil(environment.coordinator.globalShortcutErrors[.quickAdd])
        XCTAssertNotNil(environment.coordinator.globalShortcutDescription(for: .toggleAllNotesVisibility))
        fails = false
        XCTAssertNil(environment.coordinator.reloadGlobalShortcuts())
        XCTAssertFalse(environment.coordinator.hasRuntimeIssues)
    }

    func testRecordingAndStopDoNotAdvertiseUnregisteredShortcuts() throws {
        let environment = try TestEnvironment(makeHotKeyService: { _ in HotKey() })
        defer { environment.coordinator.stop(); environment.cleanUp() }
        environment.coordinator.start()
        XCTAssertNotNil(environment.coordinator.globalShortcutDescription(for: .quickAdd))
        environment.coordinator.beginShortcutRecording()
        XCTAssertNil(environment.coordinator.reloadGlobalShortcuts())
        XCTAssertNil(environment.coordinator.globalShortcutDescription(for: .quickAdd))
        XCTAssertNil(environment.coordinator.endShortcutRecording())
        XCTAssertNotNil(environment.coordinator.globalShortcutDescription(for: .quickAdd))
        environment.coordinator.stop()
        XCTAssertNil(environment.coordinator.globalShortcutDescription(for: .quickAdd))
    }

    func testBackupSaveFailureAlsoPublishesPersistentIssue() throws {
        let environment = try TestEnvironment(saveChanges: { _ in throw CocoaError(.fileWriteNoPermission) })
        defer { environment.cleanUp() }
        environment.container.mainContext.insert(TodoList(title: "Pending", isHidden: true))
        XCTAssertThrowsError(try environment.coordinator.makeBackupDocument())
        XCTAssertNotNil(environment.coordinator.persistenceError)
        XCTAssertTrue(environment.container.mainContext.hasChanges)
    }
}
