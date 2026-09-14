import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class TerminationAndMigrationTests: XCTestCase {
    func testFinalSaveFailureKeepsChangesAndSuccessfulRetryAllowsQuit() throws {
        var fails = true
        let environment = try TestEnvironment(saveChanges: { context in
            if fails { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        })
        defer { environment.cleanUp() }
        let list = TodoList(title: "Unsaved work", isHidden: true)
        environment.container.mainContext.insert(list)

        XCTAssertFalse(environment.coordinator.prepareForTermination())
        XCTAssertTrue(environment.container.mainContext.hasChanges)
        XCTAssertNotNil(environment.coordinator.persistenceError)
        XCTAssertEqual(list.title, "Unsaved work")

        fails = false
        XCTAssertTrue(environment.coordinator.prepareForTermination())
        XCTAssertNil(environment.coordinator.persistenceError)
        let verification = ModelContext(environment.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<TodoList>()).first?.title, "Unsaved work")
    }

    func testFinalSaveDoesNotAllowQuitWhileChangesRemain() throws {
        let environment = try TestEnvironment(saveChanges: { _ in })
        defer { environment.cleanUp() }
        environment.container.mainContext.insert(TodoList(title: "Pending", isHidden: true))
        XCTAssertFalse(environment.coordinator.prepareForTermination())
    }

    func testNoPendingChangesAllowsQuitWithoutSaving() throws {
        let environment = try TestEnvironment(saveChanges: { _ in XCTFail("Nothing to save") })
        defer { environment.cleanUp() }
        XCTAssertTrue(environment.coordinator.prepareForTermination())
    }

    func testMigrationFailureDoesNotMarkCompleteAndRetryPersists() throws {
        var fails = true
        let environment = try TestEnvironment(saveChanges: { context in
            if fails { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        })
        defer { environment.coordinator.stop(); environment.cleanUp() }
        let list = TodoList(title: "Legacy", isHidden: true, windowMode: .desktop)
        environment.container.mainContext.insert(list)
        try environment.container.mainContext.save()

        environment.coordinator.start(registerGlobalShortcuts: false)
        XCTAssertFalse(environment.settings.hasMigratedLegacyWindowDefaults)
        XCTAssertNotNil(environment.coordinator.persistenceError)

        fails = false
        environment.coordinator.start(registerGlobalShortcuts: false)
        XCTAssertTrue(environment.settings.hasMigratedLegacyWindowDefaults)
        let verification = ModelContext(environment.container)
        XCTAssertEqual(try verification.fetch(FetchDescriptor<TodoList>()).first?.windowMode, .normal)

        // A later user-selected desktop mode must not be migrated a second time.
        list.windowMode = .desktop
        try environment.container.mainContext.save()
        environment.coordinator.start(registerGlobalShortcuts: false)
        XCTAssertEqual(list.windowMode, .desktop)
    }

    func testMigrationMarkerBelongsToInjectedSettingsSuite() throws {
        let first = try TestEnvironment()
        let second = try TestEnvironment()
        defer {
            first.coordinator.stop(); second.coordinator.stop()
            first.cleanUp(); second.cleanUp()
        }
        first.coordinator.start(registerGlobalShortcuts: false)
        XCTAssertTrue(first.settings.hasMigratedLegacyWindowDefaults)
        XCTAssertFalse(second.settings.hasMigratedLegacyWindowDefaults)
        let legacy = TodoList(title: "Separate store", isHidden: true, windowMode: .desktop)
        second.container.mainContext.insert(legacy)
        second.coordinator.start(registerGlobalShortcuts: false)
        XCTAssertEqual(legacy.windowMode, .normal)
        XCTAssertTrue(second.settings.hasMigratedLegacyWindowDefaults)
    }
}
